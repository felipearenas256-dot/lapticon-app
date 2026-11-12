import 'package:flutter/foundation.dart';

import '../core/text.dart';
import '../data/lapticon_api.dart';

/// Avisa a las pantallas abiertas que los datos cambiaron, para que Inicio,
/// Encomiendas y Viajes se mantengan al día después de cualquier operación.
class Revision extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Pestaña visible del menú inferior.
class ShellTab extends ValueNotifier<int> {
  ShellTab() : super(0);

  static const inicio = 0;
  static const buscar = 1;
  static const encomiendas = 2;
  static const viajes = 3;
  static const perfil = 4;
}

/// Catálogos de ciudades y países, guardados en memoria tras la primera carga.
class CityCatalog {
  CityCatalog(this._api);

  final LapticonApi _api;
  Future<List<String>>? _cities;
  Future<List<String>>? _countries;
  final _byCountry = <String, Future<List<String>>>{};

  Future<List<String>> cities() => _cities ??= _cached(
        () async => dedupeCities(await _api.ciudades()),
        () => _cities = null,
      );

  Future<List<String>> countries() =>
      _countries ??= _cached(_api.paises, () => _countries = null);

  Future<List<String>> citiesOf(String country) =>
      _byCountry[country] ??= _cached(
        () async => dedupeCities(await _api.ciudadesPorPais(country)),
        () => _byCountry.remove(country),
      );

  /// Si la carga falla se olvida el resultado, para reintentar la próxima vez.
  Future<List<String>> _cached(
    Future<List<String>> Function() load,
    void Function() forget,
  ) async {
    try {
      return await load();
    } catch (_) {
      forget();
      rethrow;
    }
  }
}
