// ignore_for_file: deprecated_member_use

import 'package:macros/macros.dart';

import '../json_encoder_decoder.dart';

/// Shared logic for all macros which run in the declarations phase.
mixin Shared {
  /// Returns [type] as a [NamedTypeAnnotation] if it is one, otherwise returns
  /// `null` and emits relevant error diagnostics.
  NamedTypeAnnotation? checkNamedType(TypeAnnotation type, Builder builder) {
    if (type is NamedTypeAnnotation) return type;
    // return type;

    if (type is OmittedTypeAnnotation) {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Only fields with explicit types are allowed on serializable '
            'classes, please add a type.',
            target: type.asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
    } else {
      builder.report(
        Diagnostic(
          DiagnosticMessage(
            'Only fields with named types are allowed on serializable '
            'classes.',
            target: type.asDiagnosticTarget,
          ),
          Severity.error,
        ),
      );
    }
    return null;
  }

  /// Does some basic validation on [clazz], and shared setup logic.
  ///
  /// Returns a code representation of the [Map<String, Object?>] class.
  Future<NamedTypeAnnotationCode> setup(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    if (clazz.typeParameters.isNotEmpty) {
      throw DiagnosticException(
        Diagnostic(
          DiagnosticMessage(
            // TODO: Target the actual type parameter, issue #55611
            'Cannot be applied to classes with generic type parameters',
          ),
          Severity.error,
        ),
      );
    }

    final (map, string, object) = await (
      builder.resolveIdentifier(dartCore, 'Map'),
      builder.resolveIdentifier(dartCore, 'String'),
      builder.resolveIdentifier(dartCore, 'Object'),
    ).wait;
    return NamedTypeAnnotationCode(
      name: map,
      typeArguments: [
        NamedTypeAnnotationCode(name: string),
        NamedTypeAnnotationCode(name: object).asNullable,
      ],
    );
  }
}
