import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart';
import '../../core/app_data.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';

/// Crea o modifica un'etichetta: una tantum (tra due date) o ricorrente (riparte ogni periodo),
/// con tetto di spesa facoltativo. Chiudendosi dopo il salvataggio restituisce il nome.
class TagSheet extends StatefulWidget {
  const TagSheet({super.key, this.tag, this.initialName = ''});
  final Tag? tag;
  final String initialName;

  @override
  State<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<TagSheet> {
  late final _name = TextEditingController(text: widget.tag?.name ?? widget.initialName);
  late TagKind _kind = widget.tag?.kind ?? TagKind.oneShot;
  late DateTime _start = widget.tag?.start ?? _today;
  late DateTime _end = widget.tag?.end ?? _today.add(const Duration(days: 3));
  late TagSpan _span = widget.tag?.span ?? TagSpan.week;
  late TagUnit _unit = widget.tag?.unit ?? TagUnit.month;
  late int _every = widget.tag?.every ?? 1;
  late String _currency = widget.tag?.currency ?? 'EUR';
  late final _budget = TextEditingController(
      text: widget.tag?.budget == null
          ? ''
          : Money.formatNumber(widget.tag!.budget!, currencyFor(_currency).minorUnits, grouping: false));
  String? _error;
  bool _confirmDelete = false;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _editing => widget.tag != null;
  bool get _recurring => _kind == TagKind.recurring;

  @override
  void initState() {
    super.initState();
    // Valuta proposta: quella dei conti dell'utente.
    if (widget.tag == null) _currency = context.read<AppData>().accountCurrencies.first.code;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Tag _draft({int? budget}) => Tag(
        id: widget.tag?.id ?? '',
        name: _name.text,
        kind: _kind,
        start: _start,
        end: _end,
        span: _span,
        unit: _unit,
        every: _every,
        budget: budget,
        currency: _currency,
      );

  Future<void> _pick({required bool start}) async {
    final day = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null) return;
    setState(() {
      if (start) {
        _start = day;
        if (_end.isBefore(day)) _end = day;
      } else {
        _end = day;
      }
    });
  }

  Future<void> _save() async {
    final text = _budget.text.trim();
    int? budget;
    if (text.isNotEmpty) {
      budget = Money.parse(text, currencyFor(_currency).minorUnits);
      if (budget == null || budget <= 0) {
        setState(() => _error = 'Il tetto di spesa deve essere un importo maggiore di zero.');
        return;
      }
    }
    final draft = _draft(budget: budget);
    final error = await context.read<AppData>().saveTag(draft);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context, normalizeTagName(draft.name));
    }
  }

  Future<void> _delete() async {
    final data = context.read<AppData>();
    if (!_confirmDelete) {
      final usage = data.tagUsage(widget.tag!);
      setState(() {
        _confirmDelete = true;
        _error = usage == 0
            ? null
            : usage == 1
                ? 'Verrà tolta da 1 movimento (il movimento resta).'
                : 'Verrà tolta da $usage movimenti (i movimenti restano).';
      });
      return;
    }
    await data.deleteTag(widget.tag!.id);
    if (mounted) Navigator.pop(context);
  }

  List<Widget> _oneShotFields() {
    final end = Analytics.oneShotEnd(_start, _span, _end);
    final days = DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(_start.year, _start.month, _start.day)).inDays + 1;
    return [
      const FieldLabel('Durata'),
      Segmented<TagSpan>(
        values: TagSpan.values,
        labels: const ['Settimana', 'Mese', 'Date libere'],
        selected: _span,
        onChanged: (s) => setState(() => _span = s),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton(onPressed: () => _pick(start: true), child: Text('Dal ${numericDate(_start)}')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: _span == TagSpan.custom ? () => _pick(start: false) : null,
            child: Text('Al ${numericDate(end)}'),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Muted(
        '${days == 1 ? '1 giorno' : '$days giorni'}. Potrai metterla solo sui movimenti in queste date.',
        size: 12.5,
      ),
    ];
  }

  List<Widget> _recurringFields() {
    final (from, to) = Analytics.periodAt(_draft(), DateTime.now());
    final restart = switch (_unit) {
      TagUnit.day => _every == 1 ? 'Il conteggio riparte ogni giorno.' : 'Il conteggio riparte ogni $_every giorni.',
      TagUnit.week => 'Il conteggio riparte di lunedì.',
      TagUnit.month => 'Il conteggio riparte il primo del mese.',
      TagUnit.year => 'Il conteggio riparte il 1° gennaio.',
    };
    return [
      const FieldLabel('Si ripete'),
      Segmented<TagUnit>(
        values: TagUnit.values,
        labels: const ['Giorno', 'Settimana', 'Mese', 'Anno'],
        selected: _unit,
        onChanged: (u) => setState(() => _unit = u),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(recurrenceLabel(_unit, _every), style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton.filledTonal(
          key: const Key('every-minus'),
          onPressed: _every > 1 ? () => setState(() => _every--) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text('$_every', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        IconButton.filledTonal(
          key: const Key('every-plus'),
          onPressed: _every < 365 ? () => setState(() => _every++) : null,
          icon: const Icon(Icons.add),
        ),
      ]),
      if (_every > 1) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _pick(start: true),
          child: Text('Primo periodo dal ${numericDate(_start)}'),
        ),
      ],
      const SizedBox(height: 6),
      Muted('$restart Periodo attuale: ${tagPeriodLabel(_draft(), from, to)}. '
          'Nella scheda dell\'etichetta vedi quanto hai speso nei periodi precedenti.', size: 12.5),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currencies = context.read<AppData>().accountCurrencies;
    final currency = currencyFor(_currency);
    return SheetScaffold(
      title: _editing ? 'Modifica etichetta' : 'Nuova etichetta',
      subtitle: _recurring
          ? 'Es. autostrada, spesa, benzina: vedi quanto spendi ogni periodo e lo confronti con i precedenti.'
          : 'Es. vacanza al mare, viaggio a Rimini: vale solo tra due date.',
      fields: [
        const FieldLabel('Nome'),
        TextField(
          controller: _name,
          autofocus: !_editing && widget.initialName.isEmpty,
          decoration: InputDecoration(hintText: _recurring ? 'es. autostrada' : 'es. viaggio a Rimini'),
        ),
        const FieldLabel('Tipo'),
        Segmented<TagKind>(
          values: TagKind.values,
          labels: const ['Una tantum', 'Ricorrente'],
          selected: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        ...(_recurring ? _recurringFields() : _oneShotFields()),
        FieldLabel(_recurring ? 'Tetto di spesa per periodo (facoltativo)' : 'Tetto di spesa totale (facoltativo)'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  hintText: 'Nessun tetto, es. ${Money.formatNumber(80000, currency.minorUnits, grouping: false)}'),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _currency,
            underline: const SizedBox(),
            dropdownColor: VColors.surface,
            items: [
              for (final c in currencies) DropdownMenuItem(value: c.code, child: Text('${c.symbol} ${c.code}')),
              if (!currencies.any((c) => c.code == _currency))
                DropdownMenuItem(value: _currency, child: Text('${currency.symbol} ${currency.code}')),
            ],
            onChanged: (v) => setState(() => _currency = v ?? _currency),
          ),
        ]),
        const SizedBox(height: 6),
        Muted("Conta le uscite con questa etichetta su tutti i tuoi conti in ${currency.code}. "
            "Ti avvisiamo all'80% e quando lo superi.", size: 12),
        ErrorBox(_error),
      ],
      actions: [
        FilledButton(onPressed: _save, child: const Text('Salva')),
        if (_editing) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: VColors.negative),
            child: Text(_confirmDelete ? 'Tocca di nuovo per confermare' : 'Elimina etichetta'),
          ),
        ],
      ],
    );
  }
}
