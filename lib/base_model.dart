import 'package:harmony/json_encoder_decoder/json_encoder_decoder.dart';

@JsonEncoderDecoder()
class BaseModel {
  final String name;
  final int age;
  final DateTime dobBart;

  BaseModel(
    this.name,
    this.age,
    this.dobBart,
  );
}
