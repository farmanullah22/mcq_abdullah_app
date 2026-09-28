class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? errors;

  const ApiException({required this.statusCode, required this.message, this.errors});

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}
