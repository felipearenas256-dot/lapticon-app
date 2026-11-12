import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/text.dart';
import '../../data/lapticon_api.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

class EncomiendaFormScreen extends StatefulWidget {
  const EncomiendaFormScreen({super.key, this.origen, this.destino});

  final String? origen;
  final String? destino;

  @override
  State<EncomiendaFormScreen> createState() => _EncomiendaFormScreenState();
}

class _EncomiendaFormScreenState extends State<EncomiendaFormScreen> {
  final _form = GlobalKey<FormState>();
  final _observaciones = TextEditingController();
  final _valor = TextEditingController();
  late String? _origen = widget.origen;
  late String? _destino = widget.destino;
  String _moneda = 'USD';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _observaciones.dispose();
    _valor.dispose();
    super.dispose();
  }

  double? get _valorNumero =>
      double.tryParse(_valor.text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LapticonApi>().crearEncomienda(
            ciudadOrigen: _origen!,
            ciudadDestino: _destino!,
            observaciones: _observaciones.text.trim(),
            moneda: _moneda,
            valor: _valorNumero!,
          );
      if (!mounted) return;
      context.read<Revision>().bump();
      showMessage(context, 'Encomienda publicada.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva encomienda')),
      body: SafeArea(
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: pagePadding,
            children: [
              CityFormField(
                label: 'Origen',
                icon: Icons.trip_origin,
                initialValue: _origen,
                onPicked: (city) => setState(() => _origen = city),
              ),
              const SizedBox(height: 14),
              CityFormField(
                label: 'Destino',
                icon: Icons.place_outlined,
                initialValue: _destino,
                onPicked: (city) => setState(() => _destino = city),
                extraValidator: (city) =>
                    city != null &&
                            _origen != null &&
                            searchKey(city) == searchKey(_origen!)
                        ? 'Debe ser diferente al origen'
                        : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _observaciones,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué vas a enviar?',
                  hintText: 'Tamaño, peso aproximado y cuidados',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value ?? '').trim().length < 3
                    ? 'Describe brevemente la encomienda'
                    : null,
              ),
              const SizedBox(height: 6),
              Text('Moneda', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'USD', label: Text('USD')),
                  ButtonSegment(value: 'COP', label: Text('COP')),
                  ButtonSegment(value: 'EUR', label: Text('EUR')),
                ],
                selected: {_moneda},
                onSelectionChanged: (selection) =>
                    setState(() => _moneda = selection.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valor,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Valor',
                  suffixText: _moneda,
                ),
                validator: (_) {
                  final value = _valorNumero;
                  return value == null || value <= 0
                      ? 'Escribe un valor mayor a cero'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              BusyButton(
                label: 'Publicar encomienda',
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
