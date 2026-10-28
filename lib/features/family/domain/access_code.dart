import 'dart:convert';
import 'dart:math';

String newAccessCode() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

String? parseAccessCode(String value) {
  final code = value.trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code)) return null;
  try {
    return base64UrlEncode(base64Url.decode('$code=')).replaceAll('=', '') ==
            code
        ? code
        : null;
  } on FormatException {
    return null;
  }
}
