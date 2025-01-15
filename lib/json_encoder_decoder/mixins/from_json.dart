import 'package:harmony/json_encoder_decoder/extensions/extension_on_code.dart';
import 'package:harmony/json_encoder_decoder/extensions/first_where_or_null.dart';
import 'package:harmony/json_encoder_decoder/extensions/is_exactly.dart';
import 'package:harmony/json_encoder_decoder/extensions/name_type_annotation.dart';
import 'package:macros/macros.dart';

import '../convert_to_undercore.dart';
import '../json_encoder_decoder.dart';
import '../share_introspection_data.dart';
import 'shared.dart';

/// Shared logic for macros that want to generate a `fromJson` constructor.
mixin FromJson on Shared {
  /// Builds the actual `fromJson` constructor.
  Future<void> buildFromJson(
      ClassDeclaration clazz,
      TypeDefinitionBuilder typeBuilder,
      SharedIntrospectionData introspectionData) async {
    final constructors = await typeBuilder.constructorsOf(clazz);
    final fromJson =
        constructors.firstWhereOrNull((c) => c.identifier.name == 'fromJson');
    if (fromJson == null) return;
    await _checkValidFromJson(fromJson, introspectionData, typeBuilder);
    final builder = await typeBuilder.buildConstructor(fromJson.identifier);

    // If extending something other than `Object`, it must have a `fromJson`
    // constructor.
    var superclassHasFromJson = false;
    final superclassDeclaration = introspectionData.superclass;
    if (superclassDeclaration != null &&
        !superclassDeclaration.isExactly('Object', dartCore)) {
      final superclassConstructors =
          await builder.constructorsOf(superclassDeclaration);
      for (final superConstructor in superclassConstructors) {
        if (superConstructor.identifier.name == 'fromJson') {
          await _checkValidFromJson(
              superConstructor, introspectionData, builder);
          superclassHasFromJson = true;
          break;
        }
      }
      if (!superclassHasFromJson) {
        throw DiagnosticException(Diagnostic(
            DiagnosticMessage(
                'Serialization of classes that extend other classes is only '
                'supported if those classes have a valid '
                '`fromJson(Map<String, Object?> json)` constructor.',
                target: introspectionData.clazz.superclass?.asDiagnosticTarget),
            Severity.error));
      }
    }

    final fields = introspectionData.fields;
    final jsonParam = fromJson.positionalParameters.single.identifier;

    Future<Code> initializerForField(FieldDeclaration field) async {
      return RawCode.fromParts([
        field.identifier,
        ' = ',
        await _convertTypeFromJson(
            field.type,
            RawCode.fromParts([
              jsonParam,
              "['",
              JsonConverters.convertToUnderscore(field.identifier.name),
              "']",
            ]),
            builder,
            introspectionData),
      ]);
    }

    final initializers = await Future.wait(fields.map(initializerForField));

    if (superclassHasFromJson) {
      initializers.add(RawCode.fromParts([
        'super.fromJson(',
        jsonParam,
        ')',
      ]));
    }

    builder.augment(initializers: initializers);
  }

  /// Emits an error [Diagnostic] if there is an existing `fromJson`
  /// constructor on [clazz].
  ///
  /// Returns `true` if the check succeeded (there was no `fromJson`) and false
  /// if it didn't (a diagnostic was emitted).
  Future<bool> _checkNoFromJson(
      DeclarationBuilder builder, ClassDeclaration clazz) async {
    final constructors = await builder.constructorsOf(clazz);
    final fromJson =
        constructors.firstWhereOrNull((c) => c.identifier.name == 'fromJson');
    if (fromJson != null) {
      builder.report(Diagnostic(
          DiagnosticMessage(
              'Cannot generate a fromJson constructor due to this existing '
              'one.',
              target: fromJson.asDiagnosticTarget),
          Severity.error));
      return false;
    }
    return true;
  }

  /// Checks that [constructor] is a valid `fromJson` constructor, and throws a
  /// [DiagnosticException] if not.
  Future<void> _checkValidFromJson(
      ConstructorDeclaration constructor,
      SharedIntrospectionData introspectionData,
      DefinitionBuilder builder) async {
    if (constructor.namedParameters.isNotEmpty ||
        constructor.positionalParameters.length != 1 ||
        !(await (await builder
                .resolve(constructor.positionalParameters.single.type.code))
            .isExactly(introspectionData.jsonMapType))) {
      throw DiagnosticException(Diagnostic(
          DiagnosticMessage(
              'Expected exactly one parameter, with the type '
              'Map<String, Object?>',
              target: constructor.asDiagnosticTarget),
          Severity.error));
    }
  }

  /// Returns a [Code] object which is an expression that converts a JSON map
  /// (referenced by [jsonReference]) into an instance of type [type].
  Future<Code> _convertTypeFromJson(
      TypeAnnotation rawType,
      Code jsonReference,
      DefinitionBuilder builder,
      SharedIntrospectionData introspectionData) async {
    final type = checkNamedType(rawType, builder);
    if (type == null) {
      return RawCode.fromString(
          "throw 'Unable to deserialize type ${rawType.code.debugString}'");
    }

    // Follow type aliases until we reach an actual named type.
    var classDecl = await type.classDeclaration(builder);
    if (classDecl == null) {
      return RawCode.fromString(
          "throw 'Unable to deserialize type ${type.code.debugString}'");
    }

    var nullCheck = type.isNullable
        ? RawCode.fromParts([
            jsonReference,
            // `null` is a reserved word, we can just use it.
            ' == null ? null : ',
          ])
        : null;

    // Check for the supported core types, and deserialize them accordingly.
    if (classDecl.library.uri == dartCore) {
      switch (classDecl.identifier.name) {
        case 'List':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '[ for (final item in ',
            jsonReference,
            ' as ',
            introspectionData.jsonListCode,
            ') ',
            await _convertTypeFromJson(type.typeArguments.single,
                RawCode.fromString('item'), builder, introspectionData),
            ']',
          ]);
        case 'Set':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '{ for (final item in ',
            jsonReference,
            ' as ',
            introspectionData.jsonListCode,
            ')',
            await _convertTypeFromJson(type.typeArguments.single,
                RawCode.fromString('item'), builder, introspectionData),
            '}',
          ]);
        case 'Map':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            '{ for (final ',
            introspectionData.mapEntry,
            '(:key, :value) in (',
            jsonReference,
            ' as ',
            introspectionData.jsonMapCode,
            ').entries) key: ',
            await _convertTypeFromJson(type.typeArguments.last,
                RawCode.fromString('value'), builder, introspectionData),
            '}',
          ]);
        case 'int' || 'double' || 'num' || 'String' || 'bool':
          return RawCode.fromParts([
            jsonReference,
            ' as ',
            type.code,
          ]);
        case 'DateTime':
          return RawCode.fromParts([
            if (nullCheck != null) nullCheck,
            await builder.resolveIdentifier(dartCore, 'DateTime'),
            '.parse(',
            jsonReference,
            ' as ',
            introspectionData.stringCode,
            ')'
          ]);
      }
    }

    // Otherwise, check if `classDecl` has a `fromJson` constructor.
    final constructors = await builder.constructorsOf(classDecl);
    final fromJson =
        constructors.firstWhereOrNull((c) => c.identifier.name == 'fromJson');

    if (fromJson != null) {
      return RawCode.fromParts([
        if (nullCheck != null) nullCheck,
        fromJson.identifier,
        '(',
        jsonReference,
        ' as ',
        fromJson.positionalParameters.first.type.code,
        ')',
      ]);
    }

    // Unsupported type, report an error and return valid code that throws.
    builder.report(Diagnostic(
        DiagnosticMessage(
            'Unable to deserialize type, it must be a native JSON type or a '
            'type with a `fromJson(Map<String, Object?> json)` constructor.',
            target: type.asDiagnosticTarget),
        Severity.error));
    return RawCode.fromString(
        "throw 'Unable to deserialize type ${type.code.debugString}'");
  }

  /// Declares a `fromJson` constructor in [clazz], if one does not exist
  /// already.
  Future<void> declareFromJson(
      ClassDeclaration clazz,
      MemberDeclarationBuilder builder,
      NamedTypeAnnotationCode mapStringObject) async {
    if (!(await _checkNoFromJson(builder, clazz))) return;

    builder.declareInType(DeclarationCode.fromParts([
      // TODO(language#3580): Remove/replace 'external'?
      '  external ',
      clazz.identifier.name,
      '.fromJson(',
      mapStringObject,
      ' json);',
    ]));
  }
}
