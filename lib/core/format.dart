import 'package:intl/intl.dart';

final _dateOnly = DateFormat('d MMM y', 'es');
final _dateTime = DateFormat("d MMM y, h:mm a", 'es');
final _apiDate = DateFormat('yyyy-MM-dd');

/// Formatea una fecha sin hora, como `fechaViaje`.
///
/// La API la guarda a medianoche UTC (`2026-12-01T00:00:00.000Z`). Convertirla a
/// hora local la movería al 30 de noviembre en Colombia, así que se lee en UTC.
String formatDateOnly(DateTime? date) =>
    date == null ? 'Sin fecha' : _dateOnly.format(date.toUtc());

/// Formatea un instante real, como `fechaVencimiento`, en hora local.
String formatDateTime(DateTime? date) =>
    date == null ? 'Sin fecha' : _dateTime.format(date.toLocal());

/// Fecha elegida por el usuario en el formato que espera `POST /api/viajes`.
String toApiDate(DateTime date) => _apiDate.format(date);

String formatMoney(num? value, String? currency) {
  if (value == null) return 'Sin valor';
  final code = (currency ?? '').trim().toUpperCase();
  final decimals = value == value.roundToDouble() ? 0 : 2;
  final formatted = NumberFormat.decimalPatternDigits(
    locale: 'es_CO',
    decimalDigits: decimals,
  ).format(value);
  return code.isEmpty ? formatted : '$code $formatted';
}

String formatAverage(double? average) =>
    average == null ? 'Sin calificar' : average.toStringAsFixed(1);
