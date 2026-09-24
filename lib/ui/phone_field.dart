import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../core/countries.dart';
import 'theme.dart';
import 'widgets.dart';

/// Bandiera del paese (immagine inclusa nell'app, niente internet).
class Flag extends StatelessWidget {
  const Flag(this.iso, {super.key, this.width = 26});
  final String iso;
  final double width;

  @override
  Widget build(BuildContext context) => CountryFlag.fromCountryCode(
    iso,
    theme: ImageTheme(width: width, height: width * 0.72, shape: const RoundedRectangle(4)),
  );
}

/// Prefisso (bandiera + "+39", tocca per cambiare paese) e numero.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.country,
    required this.onCountryChanged,
    required this.controller,
    this.textInputAction,
  });

  final String country;
  final ValueChanged<String> onCountryChanged;
  final TextEditingController controller;
  final TextInputAction? textInputAction;

  Future<void> _pick(BuildContext context) async {
    final iso = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CountryPicker(selected: country),
    );
    if (iso != null) onCountryChanged(iso);
  }

  @override
  Widget build(BuildContext context) {
    final c = countryFor(country);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: VColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: VColors.border),
            ),
            child: InkWell(
              key: const Key('phone-country'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _pick(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Flag(country),
                    const SizedBox(width: 8),
                    Text(c?.dial ?? '+', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_drop_down, color: VColors.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              textInputAction: textInputAction,
              decoration: const InputDecoration(hintText: '333 1234567'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Elenco dei paesi con ricerca per nome o prefisso. Restituisce il codice ISO scelto.
class CountryPicker extends StatefulWidget {
  const CountryPicker({super.key, required this.selected});
  final String selected;

  @override
  State<CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<CountryPicker> {
  String _query = '';

  static String _plain(String s) {
    const from = 'àáâäèéêëìíîïòóôöùúûüçñ';
    const to = 'aaaaeeeeiiiioooouuuucn';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  List<Country> get _results {
    final q = _plain(_query.trim());
    if (q.isEmpty) return kCountries;
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return kCountries.where((c) {
      if (digits.isNotEmpty && q.replaceAll('+', '') == digits) return c.dial.substring(1).startsWith(digits);
      final name = _plain(c.name);
      return name.startsWith(q) || name.contains(' $q') || name.contains(q) || c.iso.toLowerCase() == q;
    }).toList()..sort((a, b) {
      // Prima quelli il cui nome inizia con la ricerca.
      final sa = _plain(a.name).startsWith(q) ? 0 : 1, sb = _plain(b.name).startsWith(q) ? 0 : 1;
      return sa - sb;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scegli il paese', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Cerca, es. Italia o 39',
                    prefixIcon: Icon(Icons.search, color: VColors.muted),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Muted('Nessun paese trovato.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final c = results[i];
                      final selected = c.iso == widget.selected;
                      return ListTile(
                        leading: Flag(c.iso, width: 30),
                        title: Text(c.name, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Muted(c.dial),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check, color: VColors.accent, size: 20),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.pop(context, c.iso),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
