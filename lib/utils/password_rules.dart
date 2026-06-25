class PasswordRules {
  const PasswordRules._();

  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  static bool hasMinimumLength(String password) => password.length >= 8;

  static bool hasLowercase(String password) => _lowercase.hasMatch(password);

  static bool hasUppercase(String password) => _uppercase.hasMatch(password);

  static bool hasDigit(String password) => _digit.hasMatch(password);

  static bool hasSymbol(String password) => _symbol.hasMatch(password);

  static bool isValid(String password) =>
      hasMinimumLength(password) &&
      hasLowercase(password) &&
      hasUppercase(password) &&
      hasDigit(password) &&
      hasSymbol(password);

  static String? validationMessage(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter a password';
    if (!hasMinimumLength(password)) return 'Use at least 8 characters';
    if (!hasLowercase(password)) return 'Add a lowercase letter';
    if (!hasUppercase(password)) return 'Add an uppercase letter';
    if (!hasDigit(password)) return 'Add a number';
    if (!hasSymbol(password)) return 'Add a symbol';
    return null;
  }
}
