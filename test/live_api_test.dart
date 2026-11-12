// Prueba de solo lectura contra el backend real. No corre por defecto:
//
//   flutter test test/live_api_test.dart --dart-define=LIVE=true
//
// Necesita config/firebase.json y config/test_account.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lapticon/data/api_client.dart';
import 'package:lapticon/data/lapticon_api.dart';

const _live = bool.fromEnvironment('LIVE');
const _baseUrl = 'https://lapticon-backend.onrender.com';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// La app usa el SDK de Firebase. Aquí basta el endpoint REST equivalente.
Future<({String token, String uid})> _signIn() async {
  final key = _readJson('config/firebase.json')['FIREBASE_API_KEY'];
  final account = _readJson('config/test_account.json');
  final response = await http.post(
    Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/'
      'accounts:signInWithPassword?key=$key',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': account['email'],
      'password': account['password'],
      'returnSecureToken': true,
    }),
  );
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return (token: json['idToken'] as String, uid: json['localId'] as String);
}

void main() {
  late LapticonApi api;
  late String uid;

  setUpAll(() async {
    if (!_live) return;
    final session = await _signIn();
    uid = session.uid;
    api = LapticonApi(
      ApiClient(
        client: http.Client(),
        baseUrl: _baseUrl,
        token: ({bool forceRefresh = false}) async => session.token,
      ),
    );
  });

  const timeout = Timeout(Duration(minutes: 3));

  test('lee el perfil de la cuenta de prueba', () async {
    final perfil = await api.perfil(uid);

    expect(perfil.nombre, 'Prueba');
    expect(perfil.nacionalidad, 'Colombia');
    expect(perfil.fechaNacimiento?.year, 2000);
  }, skip: !_live, timeout: timeout);

  test('carga los catálogos y encuentra Madrid filtrando por país', () async {
    final ciudades = await api.ciudades();
    final espana = await api.ciudadesPorPais('Spain');

    expect(ciudades, contains('Bogota'));
    expect(ciudades, isNot(contains('Madrid')));
    expect(espana, contains('Madrid'));
  }, skip: !_live, timeout: timeout);

  test('la búsqueda con tilde encuentra los viajes guardados sin tilde', () async {
    final viajes = await api.viajesDisponibles(
      origen: 'Bogotá',
      destino: 'Miami',
    );

    expect(viajes, isNotEmpty);
    expect(viajes.first.ciudadOrigen, 'Bogota');
    expect(viajes.first.fechaViaje?.isUtc, isTrue);
    expect(viajes.first.uid, isNotNull);
  }, skip: !_live, timeout: timeout);

  test('lee mis viajes y mis encomiendas', () async {
    final viajes = await api.misViajes();
    final encomiendas = await api.misEncomiendas();

    expect(viajes.first.estado, 'cancelado');
    expect(viajes.first.numeroVuelo, 'QA101');
    expect(encomiendas.first.estado, 'vencida');
    expect(encomiendas.first.valor, 1);
    expect(await api.miViajeDisponible(), isNull);
  }, skip: !_live, timeout: timeout);

  test('lee encomiendas en ruta con el nombre del remitente', () async {
    final ruta = await api.encomiendasEnRuta(origen: 'Bogotá', destino: 'Miami');

    expect(ruta.disponibles, isNotEmpty);
    expect(ruta.disponibles.first.nombreRemitente, isNotNull);
    expect(ruta.disponibles.first.uid, isNotNull);
  }, skip: !_live, timeout: timeout);

  test('lee las sugerencias con su afinidad', () async {
    final sugerencias = await api.sugerirViajes(
      ciudadOrigen: 'Bogotá',
      ciudadDestino: 'Miami',
      valorEncomienda: 1,
      fechaEncomienda: DateTime.now(),
    );

    expect(sugerencias, isNotEmpty);
    expect(sugerencias.first.id, isNotNull);
    expect(sugerencias.first.afinidad, inInclusiveRange(0, 1));
  }, skip: !_live, timeout: timeout);

  test('lee las calificaciones públicas', () async {
    final resumen = await api.calificaciones(uid);

    expect(resumen.total, 0);
    expect(resumen.promedio, isNull);
  }, skip: !_live, timeout: timeout);
}
