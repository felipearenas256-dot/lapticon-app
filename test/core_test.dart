import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lapticon/core/format.dart';
import 'package:lapticon/core/text.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('canonicalCity', () {
    test('quita tildes porque la búsqueda del backend las distingue', () {
      // Real: buscar "Bogotá" devuelve [] y "Bogota" devuelve los viajes.
      expect(canonicalCity('Bogotá'), 'Bogota');
      expect(canonicalCity('Medellín'), 'Medellin');
    });

    test('conserva la ñ y normaliza espacios', () {
      expect(canonicalCity('  Peñol  '), 'Peñol');
      expect(canonicalCity('Santa   Marta'), 'Santa Marta');
    });
  });

  test('dedupeCities une variantes del catálogo por país', () {
    expect(
      dedupeCities(['Bogotá', 'Medellin', 'Bogota', 'bogota', ' ']),
      ['Bogotá', 'Medellin'],
    );
  });

  test('searchKey ignora tildes y mayúsculas', () {
    expect(searchKey('BOGOTÁ').contains(searchKey('bogota')), isTrue);
  });

  test('initialsOf arma iniciales con nombres parciales', () {
    expect(initialsOf('Ana Gómez'), 'AG');
    expect(initialsOf('Ana María Gómez Ruiz'), 'AR');
    expect(initialsOf('Ana'), 'A');
    expect(initialsOf(null), '?');
  });

  group('formatDateOnly', () {
    test('no retrocede un día la fecha guardada a medianoche UTC', () {
      final fecha = DateTime.parse('2026-12-01T00:00:00.000Z');
      expect(formatDateOnly(fecha), startsWith('1 dic'));
    });

    test('indica cuando no hay fecha', () {
      expect(formatDateOnly(null), 'Sin fecha');
    });
  });

  test('toApiDate usa el formato de POST /api/viajes', () {
    expect(toApiDate(DateTime(2026, 12, 1)), '2026-12-01');
  });

  group('formatMoney', () {
    test('sin decimales cuando el valor es entero', () {
      expect(formatMoney(20, 'usd'), 'USD 20');
    });

    test('agrupa miles en formato colombiano', () {
      expect(formatMoney(80000, 'COP'), 'COP 80.000');
    });

    test('tolera datos ausentes', () {
      expect(formatMoney(null, 'USD'), 'Sin valor');
      expect(formatMoney(15, null), '15');
    });
  });
}
