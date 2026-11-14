// Field rules shared by all forms (the same rules the server checks)
class Validators {
  static final _name = RegExp(r"^[A-Za-zÑñ .'-]{2,50}$");
  static final _mobile = RegExp(r'^09[0-9]{9}$');
  static final _contact = RegExp(r'^0[0-9]{9,10}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _username = RegExp(r'^[A-Za-z0-9_]{4,20}$');
  static final _password = RegExp(r'^(?=.*[A-Za-z])(?=.*[0-9]).{8,}$');

  // Anything that must be filled in
  static String? required(String? value, [String message = 'Required.']) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  // First, middle, or last name
  static String? name(String? value, {bool optional = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return optional ? null : 'Required.';
    return _name.hasMatch(v) ? null : 'Use 2 to 50 letters.';
  }

  // Mobile number: 11 digits starting with 09
  static String? mobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required.';
    return _mobile.hasMatch(v) ? null : 'Use 11 digits starting with 09.';
  }

  // Pharmacy phone: landline or mobile, digits only
  static String? contactNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required.';
    return _contact.hasMatch(v) ? null : 'Use digits only, like 0333201234 or 09171234567.';
  }

  // Email address
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required.';
    return _email.hasMatch(v) ? null : 'Enter a valid email.';
  }

  // Username: 4 to 20 letters, numbers, or underscores
  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required.';
    return _username.hasMatch(v) ? null : 'Use 4 to 20 letters, numbers, or _.';
  }

  // Password: at least 8 characters with a letter and a number
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Required.';
    return _password.hasMatch(v) ? null : 'Use 8+ characters with a letter and a number.';
  }

  // Confirm password must match
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Required.';
    return value == password ? null : 'Passwords do not match.';
  }
}