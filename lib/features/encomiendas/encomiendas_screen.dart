import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lapticon_api.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/tickets.dart';
import 'encomienda_detail_screen.dart';
import 'encomienda_form_screen.dart';

const _filters = <(String, String?)>[
  ('Todas', null),
  ('Disponibles', 'disponible'),
  ('Tomadas', 'tomada'),
  ('Entregadas', 'entregada'),
  ('Recibidas', 'recibida'),
  ('Vencidas', 'vencida'),
];

class EncomiendasScreen extends StatefulWidget {
  const EncomiendasScreen({super.key});

  @override
  State<EncomiendasScreen> createState() => _EncomiendasScreenState();
}

class _EncomiendasScreenState extends State<EncomiendasScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nueva-encomienda',
        icon: const Icon(Icons.add),
        label: const Text('Nueva encomienda'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const EncomiendaFormScreen(),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                'Mis encomiendas',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final (label, value) in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _filter == value,
                        onSelected: (_) => setState(() => _filter = value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Loader<List<Encomienda>>(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                load: context.read<LapticonApi>().misEncomiendas,
                builder: (context, encomiendas, reload) {
                  final visible = _filter == null
                      ? encomiendas
                      : encomiendas.where((e) => e.estado == _filter).toList();
                  return RefreshIndicator(
                    onRefresh: reload,
                    child: visible.isEmpty
                        ? ListView(
                            children: [
                              EmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: _filter == null
                                    ? 'Aún no has enviado nada'
                                    : 'Nada en este estado',
                                message: _filter == null
                                    ? 'Publica tu primera encomienda y espera '
                                        'a que un viajero la tome.'
                                    : null,
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 96),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final encomienda = visible[index];
                              return EncomiendaTicket(
                                key: ValueKey(encomienda.id),
                                encomienda: encomienda,
                                index: index,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => EncomiendaDetailScreen(
                                      encomienda: encomienda,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
