import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Cliente HTTP con lo que este backend necesita en la práctica:
///
/// * Espera larga, porque Render apaga el servicio cuando está inactivo y la
///   primera petición puede tardar cerca de un minuto.
/// * Reintenta GET ante cortes de conexión, que ocurren de forma intermitente.
///   POST, PUT y PATCH no se reintentan para no duplicar una operación.
/// * Si un token vencido da 401, lo renueva y repite una sola vez.
class ApiClient {
  ApiClient({
    required this._client,
    required String baseUrl,
    required this._token,
    this._timeout = const Duration(seconds: 65),
    this._retryDelay = const Duration(milliseconds: 900),
    this._maxRetries = 2,
  }) : _base = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _base;
  final TokenProvider _token;
  final Duration _timeout;
  final Duration _retryDelay;
  final int _maxRetries;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    final uri = _base.replace(
      path: path,
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    var attempt = 0;
    var tokenRefreshed = false;

    while (true) {
      attempt++;
      try {
        final request = http.Request(method, uri);
        request.headers['Accept'] = 'application/json';
        if (auth) {
          final token = await _token(forceRefresh: tokenRefreshed);
          if (token == null) throw _sessionExpired;
          request.headers['Authorization'] = 'Bearer $token';
        }
        if (body != null) {
          request.headers['Content-Type'] = 'application/json; charset=utf-8';
          request.body = jsonEncode(body);
        }

        final streamed = await _client.send(request).timeout(_timeout);
        final response =
            await http.Response.fromStream(streamed).timeout(_timeout);

        if (response.statusCode == 401 && auth && !tokenRefreshed) {
          tokenRefreshed = true;
          continue;
        }
        return _decode(response);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        if (!await _shouldRetry(method, attempt)) {
          throw const ApiException(
            ApiErrorKind.timeout,
            'El servidor tardó demasiado en responder. Intenta de nuevo.',
          );
        }
      } on SocketException {
        if (!await _shouldRetry(method, attempt)) throw _noConnection;
      } on HandshakeException {
        if (!await _shouldRetry(method, attempt)) throw _noConnection;
      } on http.ClientException {
        if (!await _shouldRetry(method, attempt)) throw _noConnection;
      }
    }
  }

  Future<bool> _shouldRetry(String method, int attempt) async {
    if (method != 'GET' || attempt > _maxRetries) return false;
    await Future<void>.delayed(_retryDelay * attempt);
    return true;
  }

  dynamic _decode(http.Response response) {
    // Se decodifica a mano: `response.body` asume latin-1 si el servidor no
    // declara charset, y dañaría textos como "Token inválido".
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (text.trim().isEmpty) return null;
      try {
        return jsonDecode(text);
      } on FormatException {
        return text;
      }
    }
    throw _errorFor(status, _serverMessage(text));
  }

  String? _serverMessage(String text) {
    try {
      final json = jsonDecode(text);
      if (json is Map) {
        final message = json['error'] ?? json['message'] ?? json['mensaje'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } on FormatException {
      // Render y Express responden HTML o texto plano en algunos errores.
    }
    return null;
  }

  ApiException _errorFor(int status, String? server) {
    switch (status) {
      case 400:
      case 409:
      case 422:
        return ApiException(
          ApiErrorKind.validation,
          server ?? 'Revisa los datos e intenta de nuevo.',
          status: status,
        );
      case 401:
        return ApiException(
          ApiErrorKind.unauthenticated,
          _sessionExpired.message,
          status: status,
          detail: server,
        );
      case 403:
        return ApiException(
          ApiErrorKind.forbidden,
          server ?? 'No tienes permiso para hacer esto.',
          status: status,
        );
      case 404:
        return ApiException(
          ApiErrorKind.notFound,
          server ?? 'No encontramos lo que buscabas.',
          status: status,
        );
      default:
        // Los 5xx traen detalles internos, como el nombre de una variable de
        // entorno, que no deben llegar a la pantalla.
        return ApiException(
          ApiErrorKind.server,
          'El servidor tuvo un problema. Intenta de nuevo en unos minutos.',
          status: status,
          detail: server,
        );
    }
  }

  static const _sessionExpired = ApiException(
    ApiErrorKind.unauthenticated,
    'Tu sesión expiró. Vuelve a iniciar sesión.',
  );

  static const _noConnection = ApiException(
    ApiErrorKind.network,
    'No pudimos conectarnos. Revisa tu internet e intenta de nuevo.',
  );
}
