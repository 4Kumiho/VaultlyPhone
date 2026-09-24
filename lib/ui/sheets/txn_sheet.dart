import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tag_input.dart';
import 'tag_sheet.dart';

/// Nuovo movimento o modifica di uno esistente. Chiudendosi dopo il salvataggio di un'uscita
/// restituisce le sue etichette (per controllare i tetti di spesa).
class TxnSheet extends StatefulWidget {
  const TxnSheet({super.key, required this.account, this.txn});

  final Account account;
  final Txn? txn;

  @override
  State<TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<TxnSheet> {
  late final Currency _currency = currencyFor(widget.account.currency);
  late TxType _type = widget.txn?.type ?? TxType.expense;
  late int _categoryId = widget.txn?.categoryId ?? categoriesOf(_type).first.id;
  late DateTime _when = widget.txn?.occurredAt ?? DateTime.now();
  late final _amount = TextEditingController(
      text: widget.txn == null ? '' : Money.formatNumber(widget.txn!.amount, _currency.minorUnits, grouping: false));
  late final _description = TextEditingController(text: widget.txn?.description ?? '');
  late List<String> _tags = List.of(widget.txn?.tags ?? const []);
  String? _error;
  bool _confirmDelete = false;

  bool get _editing => widget.txn != null;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setType(TxType type) => setState(() {
        _type = type;
        _categoryId = categoriesOf(type).first.id;
      });

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    setState(() => _when = DateTime(day.year, day.month, day.day, time?.hour ?? _when.hour, time?.minute ?? _when.minute));
  }

  /// Nome nuovo: si apre la scheda per creare l'etichetta; se la si salva, va sul movimento.
  Future<void> _createTag(String name) async {
    final created = await showSheet<String>(context, TagSheet(initialName: name));
    if (created == null || !mounted) return;
    final tag = context.read<AppData>().tagNamed(created);
    if (tag != null && !_tags.any((t) => t.toLowerCase() == tag.name.toLowerCase())) {
      setState(() => _tags = [..._tags, tag.name]);
    }
  }

  Future<void> _save() async {
    final amount = Money.parse(_amount.text, _currency.minorUnits);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Inserisci un importo maggiore di zero.');
      return;
    }
    final draft = Txn(
      id: widget.txn?.id ?? '',
      accountId: widget.account.id,
      type: _type,
      categoryId: _categoryId,
      amount: amount,
      occurredAt: _when,
      description: _description.text,
      tags: _tags,
    );
    final error = await context.read<AppData>().saveTransaction(draft);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context, _type == TxType.expense ? _tags : <String>[]);
    }
  }

  Future<void> _delete() async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    await context.read<AppData>().deleteTransaction(widget.txn!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    return SheetScaffold(
      title: _editing ? 'Modifica movimento' : 'Nuovo movimento',
      subtitle: 'Conto: ${widget.account.name}',
      fields: [
        Segmented<TxType>(
          values: const [TxType.expense, TxType.income],
          labels: const ['Uscita', 'Entrata'],
          selected: _type,
          colors: const {TxType.expense: VColors.negative, TxType.income: VColors.positive},
          onChanged: _setType,
        ),
        const FieldLabel('Importo'),
        TextField(
          controller: _amount,
          autofocus: !_editing,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          decoration: InputDecoration(hintText: Money.format(0, _currency)),
        ),
        const FieldLabel('Categoria'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in categoriesOf(_type))
            ChoiceChip(
              label: Text(c.name),
              selected: c.id == _categoryId,
              onSelected: (_) => setState(() => _categoryId = c.id),
            ),
        ]),
        const FieldLabel('Data e ora'),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event, size: 18),
          label: Text('${numericDate(_when)}   ${timeOf(_when)}'),
        ),
        const FieldLabel('Descrizione'),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Facoltativa, es. "Spesa al supermercato"'),
        ),
        const FieldLabel('Etichette'),
        TagInput(
          tags: _tags,
          known: data.tagNames,
          suggestions: data.tagNamesFor(_when),
          onChanged: (tags) => setState(() => _tags = tags),
          onCreate: _createTag,
        ),
        ErrorBox(_error),
      ],
      actions: [
        FilledButton(onPressed: _save, child: const Text('Salva')),
        if (_editing) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: VColors.negative),
            child: Text(_confirmDelete ? 'Tocca di nuovo per confermare' : 'Elimina movimento'),
          ),
        ],
      ],
    );
  }
}
