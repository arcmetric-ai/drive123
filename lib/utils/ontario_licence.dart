class OntarioLicence {
  const OntarioLicence._();

  static final RegExp compactPattern = RegExp(r'^[A-Z][0-9]{14}$');
  static final RegExp displayPattern =
      RegExp(r'^[A-Z][0-9]{4}\s[0-9]{5}\s[0-9]{5}$');

  static String normalize(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool isValid(String value) {
    return compactPattern.hasMatch(normalize(value));
  }

  static String format(String value) {
    final normalized = normalize(value);
    if (!compactPattern.hasMatch(normalized)) return value.trim().toUpperCase();
    return '${normalized.substring(0, 5)} '
        '${normalized.substring(5, 10)} '
        '${normalized.substring(10)}';
  }
}
