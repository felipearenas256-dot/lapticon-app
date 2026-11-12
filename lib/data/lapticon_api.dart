import '../core/text.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'models.dart';

/// Operaciones de la API de Lapticon con tipos de la app.
class LapticonApi {
  LapticonApi(this._client);

  final ApiClient _client;

  // Usuarios

  Future<Usuario> registrarPerfil(Map<String, dynamic> datos) async {
    final json = await _client.post('/api/users/register', body: datos);
    return _usuario(json);
  }

  Future<Usuario> perfil(String uid) async =>
      _usuario(await _client.get('/api/users/${_id(uid)}'));

  /// `uid` y `email` no se pueden enviar: la API responde 400.
  Future<Usuario> actualizarPerfil(
    String uid,
    Map<String, dynamic> datos,
  ) async =>
      _usuario(await _client.put('/api/users/${_id(uid)}', body: datos));

  Usuario _usuario(dynamic json) {
    final map = json as Map<String, dynamic>;
    final user = map['user'];
    return Usuario.fromJson(user is Map<String, dynamic> ? user : map);
  }

  // Viajes

  Future<Viaje> crearViaje({
    required String numeroVuelo,
    required String ciudadOrigen,
    required String ciudadDestino,
    required String fechaViaje,
  }) async {
    final json = await _client.post('/api/viajes', body: {
      'numeroVuelo': numeroVuelo,
      'ciudadOrigen': canonicalCity(ciudadOrigen),
      'ciudadDestino': canonicalCity(ciudadDestino),
      'fechaViaje': fechaViaje,
    });
    return Viaje.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Viaje>> misViajes() async =>
      _viajes(await _client.get('/api/viajes'));

  /// Devuelve `null` cuando el usuario no tiene un viaje disponible (404).
  Future<Viaje?> miViajeDisponible() async {
    try {
      final json = await _client.get('/api/viajes/disponible');
      return json is Map<String, dynamic> ? Viaje.fromJson(json) : null;
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  Future<List<Viaje>> buscarViajerosPorOrigen(String ciudad) async => _viajes(
        await _client.get(
          '/api/viajes/buscar',
          query: {'ciudad': canonicalCity(ciudad)},
        ),
      );

  /// Pública: se puede usar sin iniciar sesión.
  Future<List<Viaje>> viajesDisponibles({
    required String origen,
    required String destino,
  }) async =>
      _viajes(
        await _client.get(
          '/api/viajes/disponibles',
          auth: false,
          query: {
            'ciudadOrigen': canonicalCity(origen),
            'ciudadDestino': canonicalCity(destino),
          },
        ),
      );

  Future<void> cambiarEstadoViaje(String id, String estado) => _client.patch(
        '/api/viajes/${_id(id)}/estado',
        body: {'estado': estado},
      );

  List<Viaje> _viajes(dynamic json) => [
        for (final item in _list(json)) Viaje.fromJson(item),
      ];

  // Encomiendas

  Future<Encomienda> crearEncomienda({
    required String ciudadOrigen,
    required String ciudadDestino,
    required String observaciones,
    required String moneda,
    required double valor,
  }) async {
    final json = await _client.post('/api/encomiendas', body: {
      'ciudadOrigen': canonicalCity(ciudadOrigen),
      'ciudadDestino': canonicalCity(ciudadDestino),
      'observaciones': observaciones,
      'moneda': moneda,
      'valor': valor,
    });
    return Encomienda.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Encomienda>> misEncomiendas() async =>
      _encomiendas(await _client.get('/api/encomiendas'));

  /// Filtros opcionales, sin nombre del remitente.
  Future<List<Encomienda>> encomiendasDisponiblesFiltradas({
    String? origen,
    String? destino,
  }) async =>
      _encomiendas(
        await _client.get(
          '/api/encomiendas/disponibles2',
          query: {
            if (origen != null) 'ciudadOrigen': canonicalCity(origen),
            if (destino != null) 'ciudadDestino': canonicalCity(destino),
          },
        ),
      );

  /// Exige origen y destino. Es el único endpoint que trae nombre y `uid` del
  /// remitente, y las encomiendas tomadas por el usuario. `/disponibles` omite
  /// el `uid`, necesario para reconocer las propias.
  Future<EncomiendasEnRuta> encomiendasEnRuta({
    required String origen,
    required String destino,
  }) async {
    final json = await _client.get(
      '/api/encomiendas/buscar',
      query: {
        'origen': canonicalCity(origen),
        'destino': canonicalCity(destino),
      },
    );
    final map = json as Map<String, dynamic>;
    return EncomiendasEnRuta(
      disponibles: _encomiendas(map['disponibles']),
      tomadas: _encomiendas(map['tomadas']),
    );
  }

  Future<void> tomarEncomienda(String id) =>
      _client.put('/api/encomiendas/tomar/${_id(id)}');

  Future<void> cambiarEstadoEncomienda(String id, String estado) =>
      _client.put(
        '/api/encomiendas/${_id(id)}/estado',
        body: {'estado': estado},
      );

  /// Sugerencias con `viajeId`, `uid`, `afinidad`, ruta y fecha.
  Future<List<Viaje>> sugerirViajes({
    required String ciudadOrigen,
    required String ciudadDestino,
    required double valorEncomienda,
    DateTime? fechaEncomienda,
  }) async {
    final json = await _client.post('/api/encomiendas/emparejar-viajes', body: {
      'ciudadOrigen': canonicalCity(ciudadOrigen),
      'ciudadDestino': canonicalCity(ciudadDestino),
      'valorEncomienda': valorEncomienda,
      if (fechaEncomienda != null)
        'fechaEncomienda': fechaEncomienda.toIso8601String(),
    });
    return _viajes(json);
  }

  List<Encomienda> _encomiendas(dynamic json) => [
        for (final item in _list(json)) Encomienda.fromJson(item),
      ];

  // Calificaciones

  Future<void> calificar({
    required String usuarioDestino,
    required String rolDestino,
    required int calificacion,
    String? comentario,
  }) =>
      _client.post('/api/ratings', body: {
        'usuarioDestino': usuarioDestino,
        'rolDestino': rolDestino,
        'calificacion': calificacion,
        if (comentario != null && comentario.isNotEmpty)
          'comentario': comentario,
      });

  /// Pública.
  Future<RatingResumen> calificaciones(String uid) async {
    final json = await _client.get('/api/ratings/${_id(uid)}', auth: false);
    return RatingResumen.fromJson(json as Map<String, dynamic>);
  }

  // Catálogos públicos

  Future<List<String>> ciudades() async =>
      _strings(await _client.get('/api/ciudades/ciudades', auth: false));

  Future<List<String>> paises() async =>
      _strings(await _client.get('/api/ciudades/paises', auth: false));

  Future<List<String>> ciudadesPorPais(String pais) async => _strings(
        await _client.get(
          '/api/ciudades/ciudades-por-pais',
          auth: false,
          query: {'nombre': pais},
        ),
      );

  /// Hoy responde 500 porque el servidor no tiene `RAPIDAPI_KEY`.
  Future<Map<String, dynamic>> vuelo(String numero, String fecha) async {
    final json =
        await _client.get('/api/vuelos/${_id(numero)}/$fecha', auth: false);
    return json is Map<String, dynamic> ? json : <String, dynamic>{};
  }

  // Asistente

  Future<String> preguntarAsistente(String mensaje) async {
    final json = await _client.post(
      '/api/chatbot',
      body: {'mensajeUsuario': mensaje},
    );
    final respuesta = json is Map ? json['respuesta'] : json;
    return respuesta?.toString().trim() ?? '';
  }

  // Utilidades

  String _id(String value) => Uri.encodeComponent(value);

  List<Map<String, dynamic>> _list(dynamic json) {
    var data = json;
    if (data is Map) {
      data = data.values.firstWhere((value) => value is List, orElse: () => []);
    }
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  List<String> _strings(dynamic json) =>
      json is List ? json.map((item) => item.toString()).toList() : const [];
}
