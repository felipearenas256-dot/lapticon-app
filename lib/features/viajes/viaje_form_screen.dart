import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/text.dart';
import '../../data/api_exception.dart';
import '../../data/lapticon_api.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

class ViajeFormScreen extends StatefulWidget {
  const ViajeFormScreen({super.key});

  @override
  State<ViajeFormScreen> createState() => _ViajeFormScreenState();
}

class _ViajeFormScreenState extends State<ViajeFormScreen> {
  final _form = GlobalKey<FormState>();
  final _vuelo = TextEditingController();
  String? _origen;
  String? _destino;
  bool _busy = false;
  bool _checking = false;
  String? _error;
  String? _flightNotice;

  DateTime? _fecha;

  @override
  void dispose() {
    _vuelo.dispose();
    super.dispose();
  }

  String get _numeroVuelo =>
      _vuelo.text.replaceAll(RegExp(r'\s'), '').toUpperCase();

  String get _fechaApi => toApiDate(_fecha!);

  Future<void> _pickDate(FormFieldState<DateTime> state) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
      helpText: 'Fecha del viaje',
    );
    if (picked == null) return;
    state.didChange(picked);
    setState(() {
      _fecha = picked;
      _flightNotice = null;
    });
  }

  Future<void> _checkFlight() async {
    if (_numeroVuelo.isEmpty || _fecha == null) {
      setState(() {
        _flightNotice = 'Escribe el número de vuelo y la fecha para verificar.';
      });
      return;
    }
    setState(() {
      _checking = true;
      _flightNotice = null;
    });
    String notice;
    try {
      await context.read<LapticonApi>().vuelo(_numeroVuelo, _fechaApi);
      notice = 'Encontramos el vuelo $_numeroVuelo.';
    } on ApiException catch (error) {
      notice = switch (error.kind) {
        ApiErrorKind.notFound =>
          'No encontramos ese vuelo. Revisa el número y la fecha.',
        ApiErrorKind.server =>
          'La verificación no está disponible ahora. Puedes registrar el '
              'viaje de todas formas.',
        _ => error.message,
      };
    }
    if (mounted) {
      setState(() {
        _checking = false;
        _flightNotice = notice;
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LapticonApi>().crearViaje(
            numeroVuelo: _numeroVuelo,
            ciudadOrigen: _origen!,
            ciudadDestino: _destino!,
            fechaViaje: _fechaApi,
          );
      if (!mounted) return;
      context.read<Revision>().bump();
      showMessage(context, 'Viaje registrado.');
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
      appBar: AppBar(title: const Text('Registrar viaje')),
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
                onPicked: (city) => setState(() => _origen = city),
              ),
              const SizedBox(height: 14),
              CityFormField(
                label: 'Destino',
                icon: Icons.place_outlined,
                onPicked: (city) => setState(() => _destino = city),
                extraValidator: (city) =>
                    city != null &&
                            _origen != null &&
                            searchKey(city) == searchKey(_origen!)
                        ? 'Debe ser diferente al origen'
                        : null,
              ),
              const SizedBox(height: 14),
              FormField<DateTime>(
                validator: (value) =>
                    value == null ? 'Elige la fecha del viaje' : null,
                builder: (state) => PickerField(
                  label: 'Fecha',
                  value: state.value == null
                      ? null
                      : formatDateOnly(
                          DateTime.utc(
                            state.value!.year,
                            state.value!.month,
                            state.value!.day,
                          ),
                        ),
                  icon: Icons.event_outlined,
                  errorText: state.errorText,
                  onTap: () => _pickDate(state),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _vuelo,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Número de vuelo',
                  hintText: 'AV204',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (_) => RegExp(r'^[A-Z0-9]{2}[0-9]{1,5}[A-Z]?$')
                        .hasMatch(_numeroVuelo)
                    ? null
                    : 'Escribe un número como AV204',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _checking ? null : _checkFlight,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(_checking ? 'Verificando…' : 'Verificar vuelo'),
                ),
              ),
              if (_flightNotice != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _flightNotice!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
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
                label: 'Registrar viaje',
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
