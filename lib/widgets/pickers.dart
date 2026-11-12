import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/text.dart';
import '../data/api_exception.dart';
import '../state/app_state.dart';

/// Campo con aspecto de entrada de texto que abre un selector.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Semantics(
      button: true,
      label: hasValue ? '$label: $value' : label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: !hasValue,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.expand_more),
            errorText: errorText,
          ),
          child: Text(
            hasValue ? value! : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Selector de ciudad que se integra con `Form`, con validación de obligatorio.
class CityFormField extends FormField<String> {
  CityFormField({
    super.key,
    required String label,
    required IconData icon,
    super.initialValue,
    bool isRequired = true,
    super.onSaved,
    void Function(String)? onPicked,
    String? Function(String?)? extraValidator,
  }) : super(
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Elige una ciudad';
            }
            return extraValidator?.call(value);
          },
          builder: (state) => PickerField(
            label: label,
            value: state.value,
            icon: icon,
            errorText: state.errorText,
            onTap: () async {
              final city = await pickCity(state.context, title: label);
              if (city == null) return;
              state.didChange(city);
              onPicked?.call(city);
            },
          ),
        );
}

Future<String?> pickCity(BuildContext context, {required String title}) {
  final catalog = context.read<CityCatalog>();
  return _showPicker(
    context,
    title: title,
    hint: 'Busca una ciudad',
    allLabel: 'Ciudades principales',
    loadAll: catalog.cities,
    loadCountries: catalog.countries,
    loadByCountry: catalog.citiesOf,
  );
}

Future<String?> pickCountry(BuildContext context, {required String title}) {
  return _showPicker(
    context,
    title: title,
    hint: 'Busca un país',
    loadAll: context.read<CityCatalog>().countries,
  );
}

Future<String?> _showPicker(
  BuildContext context, {
  required String title,
  required String hint,
  required Future<List<String>> Function() loadAll,
  String? allLabel,
  Future<List<String>> Function()? loadCountries,
  Future<List<String>> Function(String country)? loadByCountry,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _PickerSheet(
          title: title,
          hint: hint,
          allLabel: allLabel,
          loadAll: loadAll,
          loadCountries: loadCountries,
          loadByCountry: loadByCountry,
        ),
      ),
    );

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.hint,
    required this.loadAll,
    this.allLabel,
    this.loadCountries,
    this.loadByCountry,
  });

  final String title;
  final String hint;
  final String? allLabel;
  final Future<List<String>> Function() loadAll;
  final Future<List<String>> Function()? loadCountries;
  final Future<List<String>> Function(String country)? loadByCountry;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';
  String? _country;
  List<String>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final country = _country;
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = country == null
          ? await widget.loadAll()
          : await widget.loadByCountry!(country);
      if (!mounted || country != _country) return;
      setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _chooseCountry() async {
    final loadCountries = widget.loadCountries;
    if (loadCountries == null) return;
    final country = await _showPicker(
      context,
      title: 'Filtrar por país',
      hint: 'Busca un país',
      loadAll: loadCountries,
    );
    if (country == null) return;
    setState(() => _country = country);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final key = searchKey(_query);
    final visible = _items
        ?.where((item) => key.isEmpty || searchKey(item).contains(key))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(widget.title, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (widget.loadCountries != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  InputChip(
                    avatar: const Icon(Icons.public, size: 18),
                    label: Text(_country ?? widget.allLabel ?? 'Todas'),
                    tooltip: 'Filtrar por país',
                    onPressed: _chooseCountry,
                    onDeleted: _country == null
                        ? null
                        : () {
                            setState(() => _country = null);
                            _load();
                          },
                    deleteButtonTooltipMessage: 'Quitar filtro',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _results(visible)),
        ],
      ),
    );
  }

  Widget _results(List<String>? visible) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (visible == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.loadCountries == null
                ? 'Sin resultados.'
                : 'No aparece aquí. Prueba filtrando por país.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return ListTile(
          key: ValueKey(item),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(item),
          onTap: () => Navigator.pop(context, item),
        );
      },
    );
  }
}
