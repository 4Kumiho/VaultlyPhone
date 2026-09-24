import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../phone_field.dart';
import '../widgets.dart';

/// Modifica di email e telefono del profilo.
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final _email = TextEditingController(text: context.read<AppData>().email);
  late final _phone = TextEditingController(text: context.read<AppData>().phone);
  late String _phoneCountry = context.read<AppData>().phoneCountry;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await context.read<AppData>().saveProfile(email: _email.text, phoneCountry: _phoneCountry, phone: _phone.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Il tuo profilo',
      subtitle: 'Email e telefono restano solo su questo telefono, cifrati con la tua password.',
      fields: [
        const FieldLabel('Email'),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'nome@esempio.it'),
        ),
        const FieldLabel('Numero di telefono'),
        PhoneField(
          country: _phoneCountry,
          onCountryChanged: (iso) => setState(() => _phoneCountry = iso),
          controller: _phone,
        ),
        ErrorBox(_error),
      ],
      actions: [FilledButton(onPressed: _save, child: const Text('Salva'))],
    );
  }
}
