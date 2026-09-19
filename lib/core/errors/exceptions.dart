class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

/// Bitta telefon raqamiga bir nechta xodim yozuvi mos kelgan (HTTP 409,
/// `code: PHONE_AMBIGUOUS`). Server xavfsizlik uchun kirishni to'xtatgan,
/// lekin xodim o'zining tizim (badge) raqamini yuborsa kira oladi.
class PhoneAmbiguousException implements Exception {
  final String message;
  PhoneAmbiguousException(this.message);
}
