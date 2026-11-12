import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/data/models.dart';

void main() {
  test('Viaje acepta la respuesta real de /viajes/disponibles', () {
    // Copiada del backend. No trae _id, estado ni numeroVuelo.
    final json = jsonDecode(
      '{"ciudadOrigen":"Bogota","ciudadDestino":"Miami",'
      '"fechaViaje":"2026-12-01T00:00:00.000Z",'
      '"nombreUsuario":"Harold Viajero","uid":"abc"}',
    ) as Map<String, dynamic>;

    final viaje = Viaje.fromJson(json);

    expect(viaje.id, isNull);
    expect(viaje.numeroVuelo, isNull);
    expect(viaje.estado, 'disponible');
    expect(viaje.nombreUsuario, 'Harold Viajero');
    expect(viaje.fechaViaje!.isUtc, isTrue);
    expect(viaje.fechaViaje!.day, 1);
  });

  test('Viaje.activo depende del estado', () {
    Viaje conEstado(String estado) => Viaje(
          ciudadOrigen: 'Bogota',
          ciudadDestino: 'Miami',
          estado: estado,
        );

    expect(conEstado('disponible').activo, isTrue);
    expect(conEstado('contactado').activo, isTrue);
    expect(conEstado('completado').activo, isFalse);
    expect(conEstado('cancelado').activo, isFalse);
  });

  test('Encomienda conserva estados que la app no conoce', () {
    final encomienda = Encomienda.fromJson({
      '_id': 'e1',
      'uid': 'remitente',
      'ciudadOrigen': 'Bogota',
      'ciudadDestino': 'Miami',
      'observaciones': 'Caja pequeña',
      'moneda': 'USD',
      'valor': 20,
      'estado': 'en-revision',
      'viajeroId': null,
      'fechaCreacion': '2026-10-20T15:30:00.000Z',
      'fechaVencimiento': '2026-10-27T15:30:00.000Z',
    });

    expect(encomienda.id, 'e1');
    expect(encomienda.valor, 20);
    expect(encomienda.estado, 'en-revision');
    expect(encomienda.viajeroId, isNull);
  });

  test('Encomienda lee la respuesta real de /encomiendas/buscar', () {
    final encomienda = Encomienda.fromJson({
      '_id': 'e1',
      'uid': 'remitente',
      'ciudadOrigen': 'Pereira',
      'ciudadDestino': 'Quito',
      'observaciones': 'Caja',
      'moneda': 'USD',
      'valor': 1,
      'estado': 'disponible',
      'viajeroId': null,
      'fechaCreacion': '2026-11-05T00:11:02.442Z',
      'fechaVencimiento': '2026-12-05T00:11:02.442Z',
      'fechaDisponibleDesde': '2026-11-05T00:11:02.442Z',
      'fechaLimiteEntrega': null,
      'fotoUrl': null,
      '__v': 0,
      'remitenteNombre': 'Prueba',
    });

    expect(encomienda.nombreRemitente, 'Prueba');
    expect(encomienda.uid, 'remitente');
  });

  test('Viaje lee una sugerencia real de emparejar-viajes', () {
    final viaje = Viaje.fromJson({
      'viajeId': 'v1',
      'uid': 'viajero',
      'afinidad': 0.556,
      'ciudadOrigen': 'Bogota',
      'ciudadDestino': 'Miami',
      'fechaViaje': '2026-12-01T00:00:00.000Z',
    });

    expect(viaje.id, 'v1');
    expect(viaje.afinidad, 0.556);
  });

  test('copyWith de Encomienda cambia estado y viajero', () {
    const original = Encomienda(
      id: 'e1',
      ciudadOrigen: 'A',
      ciudadDestino: 'B',
    );
    final tomada = original.copyWith(estado: 'tomada', viajeroId: 'v1');

    expect(tomada.estado, 'tomada');
    expect(tomada.viajeroId, 'v1');
    expect(tomada.id, 'e1');
  });

  group('RatingResumen', () {
    test('acepta la respuesta real de un usuario sin calificaciones', () {
      final resumen = RatingResumen.fromJson(
        jsonDecode('{"total":0,"promedio":null,"calificaciones":[]}')
            as Map<String, dynamic>,
      );

      expect(resumen.total, 0);
      expect(resumen.promedio, isNull);
      expect(resumen.calificaciones, isEmpty);
    });

    test('acepta un promedio enviado como texto', () {
      final resumen = RatingResumen.fromJson({
        'total': 2,
        'promedio': '4.50',
        'calificaciones': [
          {'calificacion': 5, 'comentario': 'Excelente'},
          {'calificacion': 4},
        ],
      });

      expect(resumen.promedio, 4.5);
      expect(resumen.calificaciones.first.comentario, 'Excelente');
    });
  });

  test('Usuario une nombre y apellido sin dejar espacios sobrantes', () {
    expect(
      const Usuario(uid: 'u', nombre: 'Ana', apellido: 'Gómez').nombreCompleto,
      'Ana Gómez',
    );
    expect(const Usuario(uid: 'u', nombre: 'Ana').nombreCompleto, 'Ana');
    expect(const Usuario(uid: 'u').nombreCompleto, '');
  });
}
