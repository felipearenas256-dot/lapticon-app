import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../widgets/pickers.dart';

/// Datos de perfil que se editan en el registro y en Perfil.
class ProfileDraft {
  ProfileDraft([Usuario? usuario])
      : nombre = usuario?.nombre ?? '',
        apellido = usuario?.apellido ?? '',
        telefono = usuario?.telefono ?? '',
        nacionalidad = usuario?.nacionalidad,
        fechaNacimiento = usuario?.fechaNacimiento;

  String nombre;
  String apellido;
  String telefono;
  String? nacionalidad;
  DateTime? fechaNacimiento;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        if (nacionalidad != null) 'nacionalidad': nacionalidad,
        if (fechaNacimiento != null)
          'fechaNacimiento': toApiDate(fechaNacimiento!),
      };
}

class ProfileFields extends StatelessWidget {
  const ProfileFields({super.key, required this.draft});

  final ProfileDraft draft;

  static String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Este dato es obligatorio' : null;

  Future<void> _pickBirthday(FormFieldState<DateTime> state) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: state.context,
      initialDate: state.value ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) state.didChange(picked);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: draft.nombre,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: _required,
            onSaved: (value) => draft.nombre = value!.trim(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: draft.apellido,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: _required,
            onSaved: (value) => draft.apellido = value!.trim(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: draft.telefono,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 7 ? 'Escribe un teléfono válido' : null;
            },
            onSaved: (value) => draft.telefono = value!.trim(),
          ),
          const SizedBox(height: 14),
          FormField<String>(
            initialValue: draft.nacionalidad,
            validator: _required,
            onSaved: (value) => draft.nacionalidad = value,
            builder: (state) => PickerField(
              label: 'Nacionalidad',
              value: state.value,
              icon: Icons.public,
              errorText: state.errorText,
              onTap: () async {
                final country = await pickCountry(
                  state.context,
                  title: 'Nacionalidad',
                );
                if (country != null) state.didChange(country);
              },
            ),
          ),
          const SizedBox(height: 14),
          FormField<DateTime>(
            initialValue: draft.fechaNacimiento,
            onSaved: (value) => draft.fechaNacimiento = value,
            builder: (state) => PickerField(
              label: 'Fecha de nacimiento (opcional)',
              value: state.value == null
                  ? null
                  : formatDateOnly(
                      DateTime.utc(
                        state.value!.year,
                        state.value!.month,
                        state.value!.day,
                      ),
                    ),
              icon: Icons.cake_outlined,
              onTap: () => _pickBirthday(state),
            ),
          ),
        ],
      );
}
