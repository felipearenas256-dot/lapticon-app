import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/data/api_client.dart';
import 'package:lapticon/data/api_exception.dart';
import 'package:lapticon/data/lapticon_api.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

ApiClient _client(
  MockClientHandler handler, {
  TokenProvider? token,
}) =>
    ApiClient(
      client: MockClient(handler),
      baseUrl: 'https://api.test',
      retryDelay: Duration.zero,
      token: token ?? ({bool forceRefresh = false}) async => 't1',
    );

void main() {
  group('autenticación', () {
    test('envía el token Bearer en rutas privadas', () async {
      String? header;
      final client = _client((request) async {
        header = request.headers['Authorization'];
        return http.Response('[]', 200, headers: _json);
      });

      await client.get('/api/viajes');

      expect(header, 'Bearer t1');
    });

    test('no envía token en rutas públicas', () async {
      var headers = <String, String>{};
      final client = _client((request) async {
        headers = request.headers;
        return http.Response('[]', 200, headers: _json);
      });

      await client.get('/api/ciudades/paises', auth: false);

      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('con un 401 renueva el token y repite una vez', () async {
      final tokensUsados = <String?>[];
      final client = _client(
        token: ({bool forceRefresh = false}) async =>
            forceRefresh ? 'nuevo' : 'vencido',
        (request) async {
          tokensUsados.add(request.headers['Authorization']);
          return tokensUsados.length == 1
              ? http.Response('{"error":"Token inválido"}', 401, headers: _json)
              : http.Response('{"ok":true}', 200, headers: _json);
        },
      );

      final result = await client.post('/api/encomiendas', body: {'a': 1});

      expect(tokensUsados, ['Bearer vencido', 'Bearer nuevo']);
      expect(result, {'ok': true});
    });

    test('si el 401 persiste informa que la sesión expiró', () async {
      var calls = 0;
      final client = _client((request) async {
        calls++;
        return http.Response('{"error":"Token inválido"}', 401, headers: _json);
      });

      await expectLater(
        client.get('/api/viajes'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unauthenticated,
          ),
        ),
      );
      expect(calls, 2);
    });

    test('sin usuario no llega a llamar al servidor', () async {
      var calls = 0;
      final client = _client(
        token: ({bool forceRefresh = false}) async => null,
        (request) async {
          calls++;
          return http.Response('[]', 200);
        },
      );

      await expectLater(client.get('/api/viajes'), throwsA(isA<ApiException>()));
      expect(calls, 0);
    });
  });

  group('reintentos', () {
    test('GET se recupera de un corte de conexión', () async {
      var calls = 0;
      final client = _client((request) async {
        calls++;
        if (calls == 1) {
          throw const SocketException('Connection was reset');
        }
        return http.Response('[]', 200, headers: _json);
      });

      expect(await client.get('/api/viajes'), isEmpty);
      expect(calls, 2);
    });

    test('POST no se repite para no duplicar la operación', () async {
      var calls = 0;
      final client = _client((request) async {
        calls++;
        throw const SocketException('Connection was reset');
      });

      await expectLater(
        client.post('/api/encomiendas', body: {'a': 1}),
        throwsA(
          isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
        ),
      );
      expect(calls, 1);
    });

    test('GET se rinde después de los reintentos', () async {
      var calls = 0;
      final client = _client((request) async {
        calls++;
        throw http.ClientException('Connection closed');
      });

      await expectLater(client.get('/api/viajes'), throwsA(isA<ApiException>()));
      expect(calls, 3);
    });
  });

  group('errores', () {
    test('muestra el mensaje del servidor y respeta los acentos', () async {
      // Sin charset, como responde Express en algunos errores.
      final client = _client((request) async {
        return http.Response.bytes(
          utf8.encode('{"error":"Faltan parámetros de búsqueda."}'),
          400,
        );
      });

      await expectLater(
        client.get('/api/viajes/disponibles', auth: false),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.validation)
              .having((e) => e.message, 'message',
                  'Faltan parámetros de búsqueda.'),
        ),
      );
    });

    test('no muestra detalles internos de un 500', () async {
      final client = _client((request) async {
        return http.Response(
          '{"error":"RAPIDAPI_KEY no esta configurada en el servidor"}',
          500,
          headers: _json,
        );
      });

      await expectLater(
        client.get('/api/vuelos/AA123/2026-12-01', auth: false),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.server)
              .having(
                (e) => e.message,
                'message',
                isNot(contains('RAPIDAPI')),
              ),
        ),
      );
    });

    test('tolera un 404 en HTML, como el de Express', () async {
      final client = _client((request) async {
        return http.Response('<pre>Cannot GET /</pre>', 404);
      });

      await expectLater(
        client.get('/x', auth: false),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.notFound),
        ),
      );
    });
  });

  group('LapticonApi', () {
    LapticonApi api(MockClientHandler handler) => LapticonApi(_client(handler));

    test('quita tildes de las ciudades antes de buscar', () async {
      Uri? url;
      final lapticon = api((request) async {
        url = request.url;
        return http.Response('[]', 200, headers: _json);
      });

      await lapticon.viajesDisponibles(origen: 'Bogotá', destino: 'Miami');

      expect(url!.queryParameters['ciudadOrigen'], 'Bogota');
      expect(url!.queryParameters['ciudadDestino'], 'Miami');
    });

    test('guarda las ciudades sin tildes al crear', () async {
      Map<String, dynamic>? body;
      final lapticon = api((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'_id': 'e1', ...body!}), 201, headers: _json);
      });

      await lapticon.crearEncomienda(
        ciudadOrigen: 'Medellín',
        ciudadDestino: 'Bogotá',
        observaciones: 'Caja',
        moneda: 'USD',
        valor: 20,
      );

      expect(body!['ciudadOrigen'], 'Medellin');
      expect(body!['ciudadDestino'], 'Bogota');
    });

    test('un 404 en /viajes/disponible significa que no hay viaje', () async {
      final lapticon = api((request) async {
        return http.Response(
          '{"error":"No hay viajes disponibles"}',
          404,
          headers: _json,
        );
      });

      expect(await lapticon.miViajeDisponible(), isNull);
    });

    test('lee el perfil envuelto y el directo', () async {
      final envuelto = api((request) async {
        return http.Response('{"user":{"uid":"u1"}}', 200, headers: _json);
      });
      final directo = api((request) async {
        return http.Response('{"uid":"u2"}', 200, headers: _json);
      });

      expect((await envuelto.perfil('u1')).uid, 'u1');
      expect((await directo.actualizarPerfil('u2', {})).uid, 'u2');
    });

    test('separa disponibles y tomadas en /encomiendas/buscar', () async {
      final lapticon = api((request) async {
        return http.Response(
          jsonEncode({
            'disponibles': [
              {'_id': 'a', 'ciudadOrigen': 'A', 'ciudadDestino': 'B'},
            ],
            'tomadas': [
              {'_id': 'b', 'ciudadOrigen': 'A', 'ciudadDestino': 'B'},
            ],
          }),
          200,
          headers: _json,
        );
      });

      final ruta = await lapticon.encomiendasEnRuta(origen: 'A', destino: 'B');

      expect(ruta.disponibles.single.id, 'a');
      expect(ruta.tomadas.single.id, 'b');
    });

    test('sugerencias aceptan lista directa o envuelta', () async {
      final viaje = {'ciudadOrigen': 'A', 'ciudadDestino': 'B'};
      final directa = api((request) async {
        return http.Response(jsonEncode([viaje]), 200, headers: _json);
      });
      final envuelta = api((request) async {
        return http.Response(
          jsonEncode({
            'sugerencias': [viaje],
          }),
          200,
          headers: _json,
        );
      });

      final args = (
        ciudadOrigen: 'A',
        ciudadDestino: 'B',
        valorEncomienda: 10.0,
      );
      expect(
        await directa.sugerirViajes(
          ciudadOrigen: args.ciudadOrigen,
          ciudadDestino: args.ciudadDestino,
          valorEncomienda: args.valorEncomienda,
        ),
        hasLength(1),
      );
      expect(
        await envuelta.sugerirViajes(
          ciudadOrigen: args.ciudadOrigen,
          ciudadDestino: args.ciudadDestino,
          valorEncomienda: args.valorEncomienda,
        ),
        hasLength(1),
      );
    });
  });
}
