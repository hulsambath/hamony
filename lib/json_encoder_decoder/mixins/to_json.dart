import 'package:harmony/json_encoder_decoder/extensions/extension_on_code.dart';
import 'package:harmony/json_encoder_decoder/extensions/first_where_or_null.dart';
import 'package:harmony/json_encoder_decoder/extensions/is_exactly.dart';
import 'package:harmony/json_encoder_decoder/extensions/name_type_annotation.dart';
import 'package:macros/macros.dart';

import '../convert_to_undercore.dart';
import '../json_encoder_decoder.dart';
import '../share_introspection_data.dart';
import 'shared.dart';

/// Shared logic for macros that want to generate a `toJson` method.
mixin ToJson on Shared {
  /// Builds the actual `toJson` method.
  Future<void> buildToJson(
      ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder,
      SharedIntrospectionData introspectionData) async {
    final methods = await typeBuilder.methodsOf(clazz);
    final toJson =
        methods.firstWhereOrNull((c) => c.identifier.name == 'toJson');
    if (toJson == null) return;
    if (!(await _checkValidToJson(toJson, introspectionData, typeBuilder))) {
      return;
    }

    final builder = await typeBuilder.buildMethod(toJson.identifier);

    // If extending something other than `Object`, it must have a `toJson`
    // method.
    var superclassHasToJson = false;
    final superclassDeclaration = introspectionData.superclass;
    if (superclassDeclaration != null &&
        !superclassDeclaration.isExactly('Object', dartCore)) {
      final superclassMethods = await builder.methodsOf(superclassDeclaration);
      for (final superMethod in superclassMethods) {
        if (superMethod.identifier.name == 'toJson') {
          if (!(await _checkValidToJson(
              superMethod, introspectionData, builder))) {
            return;
          }
          superclassHasToJson = true;
          break;
        }
      }
      if (!superclassHasToJson) {
        builder.report(Diagnostic(
            DiagnosticMessage(
                'Serialization of classes that extend other classes is only '
                'supported if those classes have a valid '
                '`Map<String, Object?> toJson()` method.',
                target: introspectionData.clazz.superclass?.asDiagnosticTarget),
            Severity.error));
        return;
      }
    }

    final fields = introspectionData.fields;
    final parts = <Object>[
      '{\n    final json = ',
      if (superclassHasToJson)
        'super.toJson()'
      else ...[
        '<',
        introspectionData.stringCode,
        ', ',
        introspectionData.objectCode.asNullable,
        '>{}',
      ],
      ';\n    ',
    ];

    Future<Code> addEntryForField(FieldDeclaration field) async {
      final parts = <Object>[];
      final doNullCheck = field.type.isNullable;
      if (doNullCheck) {
        parts.addAll([
          'if (',
          field.identifier,
          // `null` is a reserved word, we can just use it.
          ' != null) {\n      ',
        ]);
      }
      parts.addAll([
        "json['",
        JsonConverters.convertToUnderscore(field.identifier.name),
        "'] = ",
        await _convertTypeToJson(
            field.type,
            RawCode.fromParts([
              field.identifier,
              if (doNullCheck) '!',
            ]),
            builder,
            introspectionData,
            // We already are doing the null check.
            omitNullCheck: true),
        ';\n    ',
      ]);
      if (doNullCheck) {
        parts.add('}\n    ');
      }
      return RawCode.fromParts(parts);
    }

    parts.addAll(await Future.wait(fields.map(addEntryForField)));

    parts.add('return json;\n  }');

    builder.augment(FunctionBodyCode.fromParts(parts));
  }

  /// Emits an error [Diagnostic] if there is an existing `toJson` method on
  /// [clazz].
  ///
  /// Returns `true` if the check succeeded (there was no `toJson`) and false
  /// if it didn't (a diagnostic was emitted).
  Future<bool> _checkNoToJson(
      DeclarationBuilder builder, ClassDeclaration clazz) async {
    final methods = await builder.methodsOf(clazz);
    final toJson =
        methods.firstWhereOrNull((m) => m.identifier.name == 'toJson');
    if (toJson != null) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Cannot generate a toJson method due to this existing one.',
              target: toJson.asDiagnosticTarget),
          Severity.error));
      return false;
    }
    return true;
  }

  /// Checks that [method] is a valid `toJson` method, and throws a
  /// [DiagnosticException] if not.
  Future<bool> _checkValidToJson(
      MethodDeclaration method,
      SharedIntrospectionData introspectionData,
      DefinitionBuilder builder) async {
    if (method.namedParameters.isNotEmpty ||
        method.positionalParameters.isNotEmpty ||
        !(await (await builder.resolve(method.returnType.code))
            .isExactly(introspectionData.jsonMapType))) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Expected no parameters, and a return type of '
              'Map<String, Object?>',
              target: method.asDiagnosticTarget),
          Severity.error));
      return false;
    }
    return true;
  }

  /// Returns a [Code] object which is an expression that converts an instance
  /// of type [rawType] (referenced by [valueReference]) into a JSON map.
  ///
  /// Null checks will be inserted if [rawType] is  nullable, unless
  /// [omitNullCheck] is `true`.
  Future<Code> _convertTypeToJson(TypeAnnotation rawType, Code valueReference,
      DefinitionBuilder builder, SharedIntrospectionData introspectionData,
      {bool omitNullCheck = false}) async {
    final type = checkNamedType(rawType, builder);
    if (type == null) {
      return RawCode.fromString(
          "throw 'Unable to serialize type ${rawType.code.debugString}'");
    }

    // Follow type aliases until we reach an actual named type.
    var classDecl = await type.classDeclaration(builder);
    if (classDecl == null) {
      return RawCode.fromString(
          "throw 'Unable to serialize type ${type.code.debugString}'");
    }

    var nullCheck = type.isNullable && !omitNullCheck
        ? RawCode.fromParts([
            valueReference,
            // `null` is a reserved word, we can just use it.
            ' == null ? null : ',
          ])
        : null;

    // Check for the supported core types, and serialize them accordingly.
    if (classDecl.library.uri == dartCore) {
      switch (classDecl.identifier.name) {
        case 'List' || 'Set':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '[ for (final item in ',
            valueReference,
            ') ',
            await _convertTypeToJson(type.typeArguments.single,
                RawCode.fromString('item'), builder, introspectionData),
            ']',
          ]);
        case 'Map':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '{ for (final ',
            introspectionData.mapEntry,
            '(:key, :value) in ',
            valueReference,
            '.entries) key: ',
            await _convertTypeToJson(type.typeArguments.last,
                RawCode.fromString('value'), builder, introspectionData),
            '}',
          ]);
        case 'int' || 'double' || 'num' || 'String' || 'bool':
          return valueReference;
        case 'DateTime':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            valueReference,
            '.toIso8601String()'
          ]);
      }
    }

    // Next, check if it has a `toJson()` method and call that.
    final methods = await builder.methodsOf(classDecl);
    final toJson = methods
        .firstWhereOrNull((c) => c.identifier.name == 'toJson')
        ?.identifier;
    if (toJson != null) {
      return RawCode.fromParts([
        if (nullCheck != null) nullCheck,
        valueReference,
        '.toJson()',
      ]);
    }

    // Unsupported type, report an error and return valid code that throws.
    builder.report(Diagnostic(
        DiagnosticMessage(
            'Unable to serialize type, it must be a native JSON type or a '
            'type with a `Map<String, Object?> toJson()` method.',
            target: type.asDiagnosticTarget),
        Severity.error));
    return RawCode.fromString(
        "throw 'Unable to serialize type ${type.code.debugString}'");
  }

  /// Declares a `toJson` method in [clazz], if one does not exist already.
  Future<void> declareToJson(
      ClassDeclaration clazz,
      MemberDeclarationBuilder builder,
      NamedTypeAnnotationCode mapStringObject) async {
    if (!(await _checkNoToJson(builder, clazz))) return;
    builder.declareInType(DeclarationCode.fromParts([
      // TODO(language#3580): Remove/replace 'external'?
      '  external ',
      mapStringObject,
      ' toJson();',
    ]));
  }
}
