enum ApiErrorKind {
  network,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  validation,
  server,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.status, this.detail});

  final ApiErrorKind kind;

  /// Texto listo para mostrar al usuario.
  final String message;
  final int? status;

  /// Texto original del servidor cuando no conviene mostrarlo tal cual.
  final String? detail;

  @override
  String toString() => 'ApiException($kind, $status): ${detail ?? message}';
}

String friendlyError(Object error) {
  if (error is ApiException) return error.message;
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
