import 'package:macros/macros.dart';

import 'mixins/from_json.dart';
import 'mixins/shared.dart';
import 'mixins/to_json.dart';
import 'share_introspection_data.dart';

final dartCore = Uri.parse('dart:core');

/// A macro which adds a `fromJson(Map<String, Object?> json)` JSON decoding
/// constructor, and a `Map<String, Object?> toJson()` JSON encoding method to a
/// class.
///
/// To use this macro, annotate your class with `@JsonCodable()` and enable the
/// macros experiment (see README.md for full instructions).
///
/// The implementations are derived from the fields defined directly on the
/// annotated class, and field names are expected to exactly match the keys of
/// the maps that they are being decoded from.
///
/// If extending any class other than [Object], then the super class is expected
/// to also have a corresponding `toJson` method and `fromJson` constructor
/// (possibly via those classes also using the macro).
///
/// Annotated classes are not allowed to have a manually defined `toJson` method
/// or `fromJson` constructor.
///
/// See also [JsonEncodable] and [JsonDecodable] if you only want either the
/// `toJson` or `fromJson` functionality.
macro class JsonEncoderDecoder
    with Shared, FromJson, ToJson
    implements ClassDeclarationsMacro, ClassDefinitionMacro {
  const JsonEncoderDecoder();

  /// Declares the `fromJson` constructor and `toJson` method, but does not
  /// implement them.
  @override
  Future<void> buildDeclarationsForClass(
      ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    final mapStringObject = await setup(clazz, builder);

    await (
      declareFromJson(
        clazz,
        builder,
        mapStringObject,
      ),
      declareToJson(
        clazz,
        builder,
        mapStringObject,
      ),
    ).wait;
  }

  /// Provides the actual definitions of the `fromJson` constructor and `toJson`
  /// method, which were declared in the previous phase.
  @override
  Future<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final introspectionData = await SharedIntrospectionData.build(
      builder,
      clazz,
    );

    await (
      buildFromJson(
        clazz,
        builder,
        introspectionData,
      ),
      buildToJson(
        clazz,
        builder,
        introspectionData,
      ),
    ).wait;
  }
}
