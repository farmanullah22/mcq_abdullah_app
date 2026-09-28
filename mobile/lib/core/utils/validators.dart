class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');

  static String? required(String? value, [String message = 'This field is required']) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  /// Accepts either an email address or a phone number.
  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email or phone is required';
    final id = value.trim();
    final isEmail = _emailRegex.hasMatch(id);
    final isPhone = RegExp(r'^\+?[0-9][0-9\s\-()]{6,20}$').hasMatch(id);
    if (!isEmail && !isPhone) return 'Enter a valid email or phone number';
    return null;
  }

  static String? password(String? value, [int min = 6]) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < min) return 'Password must be at least $min characters';
    return null;
  }

  static String? positiveNumber(String? value, [String message = 'Enter a valid number']) {
    if (value == null || value.trim().isEmpty) return message;
    final v = num.tryParse(value.trim());
    if (v == null || v < 0) return message;
    return null;
  }
}
