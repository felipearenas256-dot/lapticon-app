import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lapticon_api.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/pickers.dart';
import '../../widgets/tickets.dart';
import '../../widgets/viajeros.dart';
import '../auth/login_screen.dart';
import '../encomiendas/encomienda_detail_screen.dart';
import '../encomiendas/encomienda_form_screen.dart';

enum _Mode { viajeros, encomiendas }

typedef _Query = ({_Mode mode, String? origen, String? destino});

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.embedded = false});

  /// `true` cuando otra pantalla ya provee la barra superior.
  final bool embedded;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  _Mode _mode = _Mode.viajeros;
  String? _origen;
  String? _destino;
  _Query? _query;
  String? _problem;

  @override
  bool get wantKeepAlive => true;

  bool get _isGuest => context.read<Session>().isGuest;

  void _swap() => setState(() {
        final origen = _origen;
        _origen = _destino;
        _destino = origen;
      });

  void _search() {
    final origen = _origen;
    final destino = _destino;
    String? problem;
    if (_mode == _Mode.viajeros) {
      if (origen == null) {
        problem = 'Elige al menos la ciudad de origen.';
      } else if (destino == null && _isGuest) {
        problem = 'Elige también el destino, o inicia sesión para buscar '
            'solo por origen.';
      }
    } else if (_isGuest) {
      return _openLogin();
    }
    if (origen != null && origen == destino) {
      problem = 'El origen y el destino deben ser diferentes.';
    }
    setState(() {
      _problem = problem;
      if (problem == null) {
        _query = (mode: _mode, origen: origen, destino: destino);
      }
    });
  }

  /// Atajo desde "Tus rutas": llena la ruta y busca de una vez.
  void _searchRoute(_Mode mode, String origen, String destino) {
    setState(() {
      _mode = mode;
      _origen = origen;
      _destino = destino;
    });
    _search();
  }

  void _openLogin() => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );

  Future<List<Viaje>> _viajeros(_Query query) async {
    final api = context.read<LapticonApi>();
    final uid = context.read<Session>().uid;
    final viajes = query.destino == null
        ? await api.buscarViajerosPorOrigen(query.origen!)
        : await api.viajesDisponibles(
            origen: query.origen!,
            destino: query.destino!,
          );
    // Tu viaje también aparece, primero y marcado como tuyo, para que veas
    // cómo lo encuentran los demás.
    return [
      ...viajes.where((v) => uid != null && v.uid == uid),
      ...viajes.where((v) => uid == null || v.uid != uid),
    ];
  }

  /// Encomienda dirigida al viaje elegido: misma ruta, y el viajero la ve en
  /// "Disponibles en tu ruta" para tomarla.
  void _sendWith(Viaje viaje) {
    if (_isGuest) return _openLogin();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EncomiendaFormScreen(
          origen: viaje.ciudadOrigen,
          destino: viaje.ciudadDestino,
          viajero: viaje,
        ),
      ),
    );
  }

  Future<List<Encomienda>> _encomiendas(_Query query) async {
    final api = context.read<LapticonApi>();
    final uid = context.read<Session>().uid;
    final origen = query.origen;
    final destino = query.destino;
    final encomiendas = origen != null && destino != null
        ? (await api.encomiendasEnRuta(origen: origen, destino: destino))
            .disponibles
        : await api.encomiendasDisponiblesFiltradas(
            origen: origen,
            destino: destino,
          );
    // Las propias también aparecen, primero y marcadas: el detalle no deja
    // tomarlas.
    return [
      ...encomiendas.where((e) => uid != null && e.uid == uid),
      ...encomiendas.where((e) => uid == null || e.uid != uid),
    ];
  }

  void _publish(_Query query) {
    if (_isGuest) return _openLogin();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EncomiendaFormScreen(
          origen: query.origen,
          destino: query.destino,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final query = _query;

    final content = ListView(
      padding: pagePadding,
      children: [
        if (!widget.embedded) ...[
          Text('Buscar', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 14),
        ],
        SegmentedButton<_Mode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: _Mode.viajeros,
              icon: Icon(Icons.flight_takeoff),
              label: Text('Viajeros'),
            ),
            ButtonSegment(
              value: _Mode.encomiendas,
              icon: Icon(Icons.inventory_2_outlined),
              label: Text('Encomiendas'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) => setState(() {
            _mode = selection.first;
            _query = null;
            _problem = null;
          }),
        ),
        const SizedBox(height: 14),
        _RouteSelector(
          origen: _origen,
          destino: _destino,
          onOrigen: (city) => setState(() => _origen = city),
          onDestino: (city) => setState(() => _destino = city),
          onSwap: _swap,
          destinoOptional: !_isGuest,
        ),
        if (_problem != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _problem!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _search,
          icon: const Icon(Icons.search),
          label: Text(
            _mode == _Mode.viajeros ? 'Buscar viajeros' : 'Buscar encomiendas',
          ),
        ),
        const SizedBox(height: 18),
        if (query == null && !_isGuest)
          _MisRutas(onPick: _searchRoute),
        if (query != null)
          query.mode == _Mode.viajeros
              ? Loader<List<Viaje>>(
                  key: ValueKey(query),
                  load: () => _viajeros(query),
                  builder: (context, viajes, reload) => _ViajerosResult(
                    viajes: viajes,
                    canPublish: query.destino != null,
                    onPublish: () => _publish(query),
                    onSendWith: _sendWith,
                    miUid: context.read<Session>().uid,
                    onOpenMine: () =>
                        context.read<ShellTab>().value = ShellTab.viajes,
                  ),
                )
              : Loader<List<Encomienda>>(
                  key: ValueKey(query),
                  load: () => _encomiendas(query),
                  builder: (context, encomiendas, reload) =>
                      _EncomiendasResult(
                        encomiendas,
                        miUid: context.read<Session>().uid,
                      ),
                ),
      ],
    );

    return widget.embedded ? content : SafeArea(child: content);
  }
}

class _RouteSelector extends StatelessWidget {
  const _RouteSelector({
    required this.origen,
    required this.destino,
    required this.onOrigen,
    required this.onDestino,
    required this.onSwap,
    required this.destinoOptional,
  });

  final String? origen;
  final String? destino;
  final ValueChanged<String> onOrigen;
  final ValueChanged<String> onDestino;
  final VoidCallback onSwap;
  final bool destinoOptional;

  Future<void> _pick(
    BuildContext context,
    String title,
    ValueChanged<String> onPicked,
  ) async {
    final city = await pickCity(context, title: title);
    if (city != null) onPicked(city);
  }

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            children: [
              PickerField(
                label: 'Origen',
                value: origen,
                icon: Icons.trip_origin,
                onTap: () => _pick(context, 'Origen', onOrigen),
              ),
              const SizedBox(height: 10),
              PickerField(
                label: destinoOptional ? 'Destino (opcional)' : 'Destino',
                value: destino,
                icon: Icons.place_outlined,
                onTap: () => _pick(context, 'Destino', onDestino),
              ),
            ],
          ),
          Positioned(
            right: 44,
            child: IconButton.filledTonal(
              tooltip: 'Invertir ruta',
              onPressed: onSwap,
              icon: const Icon(Icons.swap_vert),
            ),
          ),
        ],
      );
}

class _ViajerosResult extends StatelessWidget {
  const _ViajerosResult({
    required this.viajes,
    required this.canPublish,
    required this.onPublish,
    required this.onSendWith,
    required this.miUid,
    required this.onOpenMine,
  });

  final String? miUid;
  final VoidCallback onOpenMine;

  final List<Viaje> viajes;
  final bool canPublish;
  final VoidCallback onPublish;
  final ValueChanged<Viaje> onSendWith;

  @override
  Widget build(BuildContext context) {
    final publish = OutlinedButton.icon(
      onPressed: onPublish,
      icon: const Icon(Icons.add),
      label: const Text('Publicar encomienda en esta ruta'),
    );

    if (viajes.isEmpty) {
      return EmptyState(
        icon: Icons.flight_outlined,
        title: 'Nadie viaja por esta ruta todavía',
        message: 'Publica tu encomienda y un viajero podrá tomarla.',
        action: canPublish ? publish : null,
      );
    }

    bool esMio(Viaje v) => miUid != null && v.uid == miUid;
    final otros = viajes.where((v) => !esMio(v)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          otros == 0
              ? 'Solo tu viaje va por esta ruta'
              : otros == 1
                  ? '1 viajero disponible'
                  : '$otros viajeros disponibles',
        ),
        for (final (index, viaje) in viajes.indexed)
          Padding(
            key: ValueKey('${viaje.uid}-$index'),
            padding: const EdgeInsets.only(bottom: 12),
            child: ViajeroTicket(
              viaje: viaje,
              index: index,
              mine: esMio(viaje),
              onTap: esMio(viaje)
                  ? onOpenMine
                  : () => showViajeroSheet(
                        context,
                        viaje: viaje,
                        onAction: () => onSendWith(viaje),
                      ),
            ),
          ),
        if (canPublish) ...[const SizedBox(height: 4), publish],
      ],
    );
  }
}

class _EncomiendasResult extends StatelessWidget {
  const _EncomiendasResult(this.encomiendas, {required this.miUid});

  final List<Encomienda> encomiendas;
  final String? miUid;

  @override
  Widget build(BuildContext context) {
    if (encomiendas.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No hay encomiendas en esta ruta',
        message: 'Prueba con otra ciudad o deja el destino vacío.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          encomiendas.length == 1
              ? '1 encomienda disponible'
              : '${encomiendas.length} encomiendas disponibles',
        ),
        for (final (index, encomienda) in encomiendas.indexed)
          Padding(
            key: ValueKey(encomienda.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: EncomiendaTicket(
              encomienda: encomienda,
              index: index,
              mine: miUid != null && encomienda.uid == miUid,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EncomiendaDetailScreen(encomienda: encomienda),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Antes de buscar, ofrece las rutas del propio viaje y de las encomiendas
/// publicadas, para ver con un toque cómo las encuentran los demás.
class _MisRutas extends StatelessWidget {
  const _MisRutas({required this.onPick});

  final void Function(_Mode mode, String origen, String destino) onPick;

  Future<List<(_Mode, String, String)>> _load(LapticonApi api) async {
    final results = await Future.wait([
      api.miViajeDisponible().catchError((Object _) => null),
      api.misEncomiendas().catchError((Object _) => <Encomienda>[]),
    ]);
    final viaje = results[0] as Viaje?;
    final encomiendas = results[1] as List<Encomienda>;
    final rutas = <(_Mode, String, String)>[
      if (viaje != null)
        (_Mode.viajeros, viaje.ciudadOrigen, viaje.ciudadDestino),
    ];
    for (final e in encomiendas.where((e) => e.estado == 'disponible')) {
      final ruta = (_Mode.encomiendas, e.ciudadOrigen, e.ciudadDestino);
      if (!rutas.contains(ruta)) rutas.add(ruta);
    }
    return rutas.take(4).toList();
  }

  @override
  Widget build(BuildContext context) => Loader<List<(_Mode, String, String)>>(
        load: () => _load(context.read<LapticonApi>()),
        placeholder: const SizedBox.shrink(),
        builder: (context, rutas, _) {
          if (rutas.isEmpty) {
            return const EmptyState(
              icon: Icons.travel_explore,
              title: 'Elige una ruta',
              message: 'Busca viajeros que lleven tu encomienda, o '
                  'encomiendas que puedas llevar en tu viaje.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Tus rutas'),
              for (final (mode, origen, destino) in rutas)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      mode == _Mode.viajeros
                          ? Icons.flight_takeoff
                          : Icons.inventory_2_outlined,
                    ),
                    title: Text('$origen → $destino'),
                    subtitle: Text(
                      mode == _Mode.viajeros
                          ? 'Tu viaje: ver quién más va'
                          : 'Tu encomienda: ver la ruta',
                    ),
                    trailing: const Icon(Icons.search),
                    onTap: () => onPick(mode, origen, destino),
                  ),
                ),
            ],
          );
        },
      );
}
