import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Backend en memoria para el modo demo y las pruebas.
///
/// Replica lo observado en la API real: un solo viaje disponible por usuario,
/// nadie toma ni califica lo propio, una encomienda no se toma dos veces,
/// `cancelada` no es un estado válido, y `/api/vuelos` y `/api/chatbot` fallan.
///
/// Con [withSampleData] en `false` arranca vacío: solo la cuenta demo, sin
/// viajes, encomiendas, calificaciones ni otros usuarios.
http.Client demoClient({
  Duration latency = const Duration(milliseconds: 250),
  bool withSampleData = true,
}) {
  final backend = _DemoBackend(withSampleData: withSampleData);
  return MockClient((request) async {
    await Future<void>.delayed(latency);
    return backend.handle(request);
  });
}

const demoUid = 'demo-usuario';

class _DemoBackend {
  _DemoBackend({bool withSampleData = true}) {
    if (!withSampleData) return;
    final now = DateTime.now().toUtc();
    String inDays(int days) => now.add(Duration(days: days)).toIso8601String();
    String dateIn(int days) {
      final day = now.add(Duration(days: days));
      return DateTime.utc(day.year, day.month, day.day).toIso8601String();
    }

    _viajes.addAll([
      {
        '_id': 'v1',
        'uid': demoUid,
        'numeroVuelo': 'AV204',
        'ciudadOrigen': 'Bogota',
        'ciudadDestino': 'Miami',
        'fechaViaje': dateIn(12),
        'estado': 'disponible',
      },
      {
        '_id': 'v2',
        'uid': demoUid,
        'numeroVuelo': 'LA951',
        'ciudadOrigen': 'Medellin',
        'ciudadDestino': 'Lima',
        'fechaViaje': dateIn(-30),
        'estado': 'completado',
      },
      {
        '_id': 'v3',
        'uid': 'u-carlos',
        'nombreUsuario': 'Carlos Ruiz',
        'numeroVuelo': 'AA920',
        'ciudadOrigen': 'Bogota',
        'ciudadDestino': 'Miami',
        'fechaViaje': dateIn(5),
        'estado': 'disponible',
      },
      {
        '_id': 'v4',
        'uid': 'u-lucia',
        'nombreUsuario': 'Lucía Mora',
        'numeroVuelo': 'AV18',
        'ciudadOrigen': 'Bogota',
        'ciudadDestino': 'Miami',
        'fechaViaje': dateIn(9),
        'estado': 'disponible',
      },
    ]);

    _encomiendas.addAll([
      {
        '_id': 'e1',
        'uid': demoUid,
        'ciudadOrigen': 'Bogota',
        'ciudadDestino': 'Miami',
        'observaciones': 'Documentos en sobre sellado',
        'moneda': 'USD',
        'valor': 20,
        'estado': 'disponible',
        'viajeroId': null,
        'fechaCreacion': inDays(-1),
        'fechaVencimiento': inDays(6),
      },
      {
        '_id': 'e2',
        'uid': demoUid,
        'ciudadOrigen': 'Cali',
        'ciudadDestino': 'Panama City',
        'observaciones': 'Regalo de cumpleaños, caja pequeña',
        'moneda': 'USD',
        'valor': 35,
        'estado': 'tomada',
        'viajeroId': 'u-carlos',
        'fechaCreacion': inDays(-4),
        'fechaVencimiento': inDays(3),
      },
      {
        '_id': 'e3',
        'uid': demoUid,
        'ciudadOrigen': 'Medellin',
        'ciudadDestino': 'Lima',
        'observaciones': 'Libros universitarios',
        'moneda': 'COP',
        'valor': 80000,
        'estado': 'recibida',
        'viajeroId': 'u-lucia',
        'fechaCreacion': inDays(-40),
        'fechaVencimiento': inDays(-33),
      },
      {
        '_id': 'e4',
        'uid': 'u-marta',
        'remitenteNombre': 'Marta Díaz',
        'ciudadOrigen': 'Bogota',
        'ciudadDestino': 'Miami',
        'observaciones': 'Medicamentos con fórmula, 500 g',
        'moneda': 'USD',
        'valor': 25,
        'estado': 'disponible',
        'viajeroId': null,
        'fechaCreacion': inDays(-2),
        'fechaVencimiento': inDays(8),
      },
      {
        '_id': 'e5',
        'uid': 'u-jorge',
        'remitenteNombre': 'Jorge Peña',
        'ciudadOrigen': 'Bogota',
        'ciudadDestino': 'Miami',
        'observaciones': 'Ropa de bebé',
        'moneda': 'USD',
        'valor': 15,
        'estado': 'tomada',
        'viajeroId': demoUid,
        'fechaCreacion': inDays(-3),
        'fechaVencimiento': inDays(7),
      },
    ]);

    _ratings['u-carlos'] = [
      {
        'usuarioOrigen': 'u-marta',
        'usuarioDestino': 'u-carlos',
        'rolDestino': 'viajero',
        'calificacion': 5,
        'comentario': 'Muy puntual y atento con el paquete.',
        'timestamp': inDays(-20),
      },
      {
        'usuarioOrigen': 'u-jorge',
        'usuarioDestino': 'u-carlos',
        'rolDestino': 'viajero',
        'calificacion': 4,
        'comentario': 'Todo bien, entregó el mismo día.',
        'timestamp': inDays(-45),
      },
    ];
    _ratings[demoUid] = [
      {
        'usuarioOrigen': 'u-marta',
        'usuarioDestino': demoUid,
        'rolDestino': 'viajero',
        'calificacion': 5,
        'comentario': 'Excelente comunicación.',
        'timestamp': inDays(-15),
      },
    ];
  }

  final _viajes = <Map<String, dynamic>>[];
  final _encomiendas = <Map<String, dynamic>>[];
  final _ratings = <String, List<Map<String, dynamic>>>{};
  var _nextId = 100;

  var _usuario = <String, dynamic>{
    'uid': demoUid,
    'email': 'ana@ejemplo.com',
    'correo': 'ana@ejemplo.com',
    'nombre': 'Ana',
    'apellido': 'Gómez',
    'telefono': '3001234567',
    'nacionalidad': 'Colombia',
    'fechaNacimiento': '1998-05-14',
  };

  static const _cities = [
    'Barranquilla', 'Bogotá', 'Bogota', 'Bucaramanga', 'Cali', 'Cartagena',
    'Lima', 'Medellin', 'Mexico City', 'Miami', 'New York', 'Panama City',
    'Pereira', 'Quito', 'San Andres', 'Santa Marta',
  ];
  static const _estadosEncomienda = [
    'disponible', 'tomada', 'vencida', 'entregada', 'recibida',
  ];
  static const _countries = ['Colombia', 'Ecuador', 'Peru', 'Spain', 'United States'];

  http.Response handle(http.Request request) {
    final path = request.url.pathSegments.skip(1).toList();
    final query = request.url.queryParameters;
    final method = request.method;
    final body = request.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final resource = path.isEmpty ? '' : path.first;
    final tail = path.skip(1).toList();

    return switch (resource) {
      'users' => _users(method, tail, body),
      'viajes' => _viajesRoute(method, tail, query, body),
      'encomiendas' => _encomiendasRoute(method, tail, query, body),
      'ratings' => _ratingsRoute(method, tail, body),
      'ciudades' => _ciudades(tail),
      'vuelos' => _json({'error': 'RAPIDAPI_KEY no está configurada en el servidor'}, 500),
      'chatbot' => _json({'error': 'Error al generar respuesta con OpenRouter'}, 500),
      _ => _json({'error': 'No encontrado'}, 404),
    };
  }

  http.Response _users(
    String method,
    List<String> tail,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST') {
      _usuario = {..._usuario, ...body};
      return _json({'message': 'Usuario guardado', 'user': _usuario}, 201);
    }
    if (method == 'PUT') {
      _usuario = {..._usuario, ...body};
      return _json(_usuario);
    }
    return _json({'user': _usuario});
  }

  http.Response _viajesRoute(
    String method,
    List<String> tail,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    final own = _viajes.where((v) => v['uid'] == demoUid);
    if (tail.isEmpty && method == 'POST') {
      if (own.any((v) => v['estado'] == 'disponible')) {
        return _json({'error': 'Ya tienes un viaje disponible'}, 400);
      }
      final viaje = {
        ...body,
        '_id': 'v${_nextId++}',
        'uid': demoUid,
        'estado': 'disponible',
        'fechaViaje': '${body['fechaViaje']}T00:00:00.000Z',
      };
      _viajes.insert(0, viaje);
      return _json(viaje, 201);
    }
    if (tail.isEmpty) return _json(own.toList());
    if (tail.length == 2 && tail.last == 'estado') {
      final viaje = _find(_viajes, tail.first);
      if (viaje == null) return _json({'error': 'No encontrado'}, 404);
      viaje['estado'] = body['estado'];
      return _json({'message': 'Estado actualizado', 'viaje': viaje});
    }
    switch (tail.first) {
      case 'disponible':
        final active = own.where((v) => v['estado'] == 'disponible');
        return active.isEmpty
            ? _json({'error': 'No hay viajes disponibles'}, 404)
            : _json(active.first);
      case 'buscar':
        return _json(
          _viajesDe(query['ciudad'], null, incluirPropios: true)
              .map(_conNombre)
              .toList(),
        );
      case 'disponibles':
        return _json(
          // Como la API real, la búsqueda pública incluye también los viajes
          // de quien busca.
          _viajesDe(
            query['ciudadOrigen'],
            query['ciudadDestino'],
            incluirPropios: true,
          )
              .map((v) => {
                    'ciudadOrigen': v['ciudadOrigen'],
                    'ciudadDestino': v['ciudadDestino'],
                    'fechaViaje': v['fechaViaje'],
                    'nombreUsuario': _conNombre(v)['nombreUsuario'],
                    'uid': v['uid'],
                  })
              .toList(),
        );
    }
    return _json({'error': 'No encontrado'}, 404);
  }

  Map<String, dynamic> _conNombre(Map<String, dynamic> v) => {
        ...v,
        'nombreUsuario': v['uid'] == demoUid
            ? '${_usuario['nombre']} ${_usuario['apellido']}'.trim()
            : v['nombreUsuario'] ?? 'Anónimo',
      };

  List<Map<String, dynamic>> _viajesDe(
    String? origen,
    String? destino, {
    bool incluirPropios = false,
  }) =>
      _viajes.where((v) {
        return v['estado'] == 'disponible' &&
            (incluirPropios || v['uid'] != demoUid) &&
            _same(v['ciudadOrigen'], origen) &&
            (destino == null || _same(v['ciudadDestino'], destino));
      }).toList();

  http.Response _encomiendasRoute(
    String method,
    List<String> tail,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) {
    if (tail.isEmpty && method == 'POST') {
      final now = DateTime.now().toUtc();
      final encomienda = {
        ...body,
        '_id': 'e${_nextId++}',
        'uid': demoUid,
        'estado': 'disponible',
        'viajeroId': null,
        'fechaCreacion': now.toIso8601String(),
        'fechaVencimiento':
            now.add(const Duration(days: 7)).toIso8601String(),
      };
      _encomiendas.insert(0, encomienda);
      return _json(encomienda, 201);
    }
    if (tail.isEmpty) {
      return _json(_encomiendas.where((e) => e['uid'] == demoUid).toList());
    }
    if (tail.first == 'tomar') {
      final encomienda = _find(_encomiendas, tail.last);
      if (encomienda == null) return _json({'error': 'No encontrada'}, 404);
      if (encomienda['uid'] == demoUid) {
        return _json({'error': 'No puedes tomar tu propia encomienda'}, 403);
      }
      if (encomienda['estado'] != 'disponible') {
        return _json({'error': 'La encomienda ya fue tomada o venció'}, 400);
      }
      encomienda['estado'] = 'tomada';
      encomienda['viajeroId'] = demoUid;
      return _json({'message': 'Encomienda tomada', 'encomienda': encomienda});
    }
    if (tail.length == 2 && tail.last == 'estado') {
      final encomienda = _find(_encomiendas, tail.first);
      if (encomienda == null) return _json({'error': 'No encontrada'}, 404);
      if (!_estadosEncomienda.contains(body['estado'])) {
        return _json({
          'error': 'Estado inválido. Debe ser uno de: '
              '${_estadosEncomienda.join(', ')}',
        }, 400);
      }
      encomienda['estado'] = body['estado'];
      return _json({'message': 'Estado actualizado', 'encomienda': encomienda});
    }
    switch (tail.first) {
      case 'disponibles':
        return _json(_disponibles(query['origen'], query['destino']));
      case 'disponibles2':
        return _json(
          _disponibles(query['ciudadOrigen'], query['ciudadDestino']),
        );
      case 'buscar':
        return _json({
          'disponibles': _disponibles(query['origen'], query['destino']),
          'tomadas': _encomiendas
              .where((e) => e['viajeroId'] == demoUid)
              .toList(),
        });
      case 'emparejar-viajes':
        return _json(
          _viajesDe(
            body['ciudadOrigen'] as String?,
            body['ciudadDestino'] as String?,
          )
              .map((v) => {
                    'viajeId': v['_id'],
                    'uid': v['uid'],
                    'afinidad': 0.556,
                    'ciudadOrigen': v['ciudadOrigen'],
                    'ciudadDestino': v['ciudadDestino'],
                    'fechaViaje': v['fechaViaje'],
                  })
              .toList(),
        );
    }
    return _json({'error': 'No encontrado'}, 404);
  }

  /// Como la API real, incluye también las encomiendas de quien busca.
  List<Map<String, dynamic>> _disponibles(String? origen, String? destino) =>
      _encomiendas.where((e) {
        return e['estado'] == 'disponible' &&
            (origen == null || _same(e['ciudadOrigen'], origen)) &&
            (destino == null || _same(e['ciudadDestino'], destino));
      }).toList();

  http.Response _ratingsRoute(
    String method,
    List<String> tail,
    Map<String, dynamic> body,
  ) {
    if (method == 'POST') {
      if (body['usuarioDestino'] == demoUid) {
        return _json({'error': 'No puedes calificarte a ti mismo'}, 400);
      }
      final rating = {
        ...body,
        'usuarioOrigen': demoUid,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      (_ratings[body['usuarioDestino']] ??= []).insert(0, rating);
      return _json(rating, 201);
    }
    final list = _ratings[tail.first] ?? const [];
    final sum = list.fold<num>(0, (acc, r) => acc + (r['calificacion'] as num));
    return _json({
      'total': list.length,
      'promedio': list.isEmpty ? null : sum / list.length,
      'calificaciones': list,
    });
  }

  http.Response _ciudades(List<String> tail) => switch (tail.first) {
        'paises' => _json(_countries),
        _ => _json(_cities),
      };

  Map<String, dynamic>? _find(List<Map<String, dynamic>> list, String id) {
    for (final item in list) {
      if (item['_id'] == id) return item;
    }
    return null;
  }

  bool _same(Object? a, String? b) =>
      '$a'.toLowerCase() == (b ?? '').toLowerCase();

  http.Response _json(Object? data, [int status = 200]) => http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
