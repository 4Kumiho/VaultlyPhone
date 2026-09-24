import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../theme.dart';
import '../widgets.dart';

/// Crea un conto o ne modifica nome e saldo iniziale; eliminazione con doppio tocco.
class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key, this.account});
  final Account? account;

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _balance = TextEditingController(
      text: widget.account == null
          ? ''
          : Money.formatNumber(widget.account!.initialBalance, currencyFor(widget.account!.currency).minorUnits,
              grouping: false));
  late String _currency = widget.account?.currency ?? 'EUR';
  String? _error;
  bool _confirmDelete = false;

  bool get _editing => widget.account != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minor = currencyFor(_currency).minorUnits;
    final text = _balance.text.trim();
    final balance = text.isEmpty ? 0 : Money.parse(text, minor);
    if (balance == null) {
      setState(() => _error = 'Saldo iniziale non valido.');
      return;
    }
    final error = await context.read<AppData>().saveAccount(
          id: widget.account?.id,
          name: _name.text,
          currency: _currency,
          initialBalance: balance,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final data = context.read<AppData>();
    if (!_confirmDelete) {
      final count = data.transactionsOf(widget.account!.id).length;
      setState(() {
        _confirmDelete = true;
        _error = count == 0
            ? null
            : count == 1
                ? 'Eliminando il conto perderai anche il suo movimento.'
                : 'Eliminando il conto perderai anche i suoi $count movimenti.';
      });
      return;
    }
    await data.deleteAccount(widget.account!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = currencyFor(_currency);
    return SheetScaffold(
      title: _editing ? 'Modifica conto' : 'Nuovo conto',
      subtitle: _editing
          ? 'Puoi correggere il nome o il saldo iniziale: il saldo attuale si ricalcola da solo.'
          : "Scegli un nome, la valuta e quanto c'è sul conto oggi.",
      fields: [
        const FieldLabel('Nome'),
        TextField(
          controller: _name,
          autofocus: !_editing,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'es. Conto corrente, Carta, Contanti'),
        ),
        const FieldLabel('Valuta'),
        if (_editing)
          Muted('${currency.symbol}  ${currency.code} · la valuta non si può cambiare dopo la creazione.')
        else
          Wrap(spacing: 8, children: [
            for (final c in kCurrencies)
              ChoiceChip(
                label: Text('${c.symbol} ${c.code}'),
                selected: c.code == _currency,
                onSelected: (_) => setState(() => _currency = c.code),
              ),
          ]),
        const FieldLabel('Saldo iniziale'),
        TextField(
          controller: _balance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(hintText: Money.format(0, currency)),
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
            child: Text(_confirmDelete ? 'Tocca di nuovo per confermare' : 'Elimina conto'),
          ),
        ],
      ],
    );
  }
}
