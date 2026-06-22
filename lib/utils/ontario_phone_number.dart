class OntarioPhoneNumber {
  OntarioPhoneNumber._();

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String? toLocalTenDigits(String? value) {
    final digits = digitsOnly(value?.trim() ?? '');
    if (digits.length == 10) return digits;
    if (digits.length == 11 && digits.startsWith('1')) {
      return digits.substring(1);
    }
    return null;
  }

  static String? toE164(String? value) {
    final local = toLocalTenDigits(value);
    return local == null ? null : '+1$local';
  }

  static bool isValid(String? value) => toE164(value) != null;

  static String displayLocal(String? value) => toLocalTenDigits(value) ?? '';
}
