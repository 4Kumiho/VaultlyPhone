import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../theme.dart';

/// Etichette di un movimento: chip con la ×, campo per aggiungerne (Invio o virgola)
/// e suggerimenti tra quelle utilizzabili. Un nome che non esiste ancora va a `onCreate`
/// (si sceglie se è una tantum o ricorrente).
class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.tags,
    required this.known,
    required this.suggestions,
    required this.onChanged,
    required this.onCreate,
  });

  final List<String> tags;
  final List<String> known; // tutte le etichette esistenti
  final List<String> suggestions; // quelle che vanno bene per la data del movimento
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<String> onCreate;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = normalizeTagName(raw);
    _text.clear();
    if (tag.isEmpty || widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      setState(() {});
      return;
    }
    final existing = widget.known.where((t) => t.toLowerCase() == tag.toLowerCase()).firstOrNull;
    if (existing == null) {
      setState(() {});
      widget.onCreate(tag);
      return;
    }
    widget.onChanged([...widget.tags, existing]);
  }

  @override
  Widget build(BuildContext context) {
    final query = _text.text.trim().toLowerCase();
    final suggestions = widget.suggestions
        .where((s) => !widget.tags.any((t) => t.toLowerCase() == s.toLowerCase()))
        .where((s) => query.isEmpty || s.toLowerCase().contains(query))
        .take(8)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag),
                labelStyle: const TextStyle(color: Color(0xFFB5C9FF), fontWeight: FontWeight.w600),
                backgroundColor: VColors.accent.withValues(alpha: 0.18),
                side: BorderSide.none,
                deleteIconColor: const Color(0xFF8FA8E0),
                onDeleted: () => widget.onChanged(widget.tags.where((t) => t != tag).toList()),
              ),
          ]),
        ),
      TextField(
        controller: _text,
        textInputAction: TextInputAction.done,
        onChanged: (v) {
          if (v.contains(',')) {
            final parts = v.split(',');
            for (final p in parts.take(parts.length - 1)) {
              _add(p);
            }
            _text.text = parts.last.trim();
          }
          setState(() {});
        },
        onSubmitted: _add,
        decoration: InputDecoration(
          hintText: 'Cerca o crea, es. autostrada',
          suffixIcon: query.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.add_circle, color: VColors.accent), onPressed: () => _add(_text.text)),
        ),
      ),
      if (suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in suggestions)
              ActionChip(
                label: Text('+ $s'),
                labelStyle: const TextStyle(color: VColors.muted, fontSize: 12.5),
                onPressed: () => _add(s),
              ),
          ]),
        ),
    ]);
  }
}
