class JsonConverters {
  const JsonConverters._();

  static String convertToUnderscore(String input) {
    return input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
      return '${match.group(1)}_${match.group(2)?.toLowerCase()}';
    });
  }
}
