const _sinTilde = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A',
  'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
  'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
  'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
  'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
};

/// Quita tildes y conserva la ñ, que en español es otra letra.
String stripAccents(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    out.write(_sinTilde[char] ?? char);
  }
  return out.toString();
}

/// Nombre de ciudad tal como se envía a la API.
///
/// El backend ignora mayúsculas pero no tildes, y sus catálogos mezclan
/// variantes: `/ciudades-por-pais` trae "Bogotá" y "Bogota", mientras los viajes
/// guardados dicen "Bogota". Buscar "Bogotá" devuelve vacío aunque haya datos,
/// por eso toda ciudad pasa por aquí antes de salir de la app.
String canonicalCity(String city) =>
    stripAccents(city).trim().replaceAll(RegExp(r'\s+'), ' ');

/// Clave para comparar y filtrar sin importar tildes ni mayúsculas.
String searchKey(String text) => canonicalCity(text).toLowerCase();

/// Elimina variantes de una misma ciudad y conserva la primera escritura.
List<String> dedupeCities(Iterable<String> cities) {
  final seen = <String>{};
  return [
    for (final city in cities)
      if (city.trim().isNotEmpty && seen.add(searchKey(city))) city.trim(),
  ];
}

String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters1;
  final last = parts.length > 1 ? parts.last.characters1 : '';
  return (first + last).toUpperCase();
}

extension on String {
  String get characters1 => isEmpty ? '' : String.fromCharCode(runes.first);
}
