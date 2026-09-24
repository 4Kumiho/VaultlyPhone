import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/app_data.dart';
import '../core/models.dart';
import '../core/money.dart';
import 'account_screen.dart';
import 'avatar.dart';
import 'balance_chart.dart';
import 'format.dart';
import 'home_screen.dart';
import 'sheets/account_sheet.dart';
import 'sheets/txn_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sezione "Conti": schede dei conti, saldo, grafico e movimenti del conto scelto.
class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  String? _selectedId;
  Period _period = Period.month;
  bool _askedFirstAccount = false;

  Future<void> _openTxn(AppData data, Account account, [Txn? txn]) async {
    final expenseTags = await showSheet<List<String>>(context, TxnSheet(account: account, txn: txn));
    if (expenseTags != null && expenseTags.isNotEmpty && mounted) {
      warnAboutBudgets(context, data, onlyTags: expenseTags);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final accounts = data.accounts;
    final selected = accounts.where((a) => a.id == _selectedId).firstOrNull ?? accounts.firstOrNull;

    // Primo accesso: si propone subito di creare un conto.
    if (accounts.isEmpty && !_askedFirstAccount) {
      _askedFirstAccount = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSheet(context, const AccountSheet());
      });
    }

    return Scaffold(
      floatingActionButton: selected == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openTxn(data, selected),
              icon: const Icon(Icons.add),
              label: const Text('Movimento', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(data: data)),
            SliverToBoxAdapter(
              child: _AccountStrip(
                data: data,
                accounts: accounts,
                selectedId: selected?.id,
                onSelect: (id) => setState(() => _selectedId = id),
              ),
            ),
            if (selected == null)
              const SliverToBoxAdapter(child: _EmptyAccounts())
            else
              ..._accountSlivers(data, selected),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  List<Widget> _accountSlivers(AppData data, Account account) {
    final currency = currencyFor(account.currency);
    final txs = data.transactionsOf(account.id);
    final now = DateTime.now();
    var end = now;
    for (final t in txs) {
      if (t.occurredAt.isAfter(end)) end = t.occurredAt;
    }
    final from = Analytics.periodStart(_period, now, txs);
    final points = Analytics.steps(account.initialBalance, txs, from, end);
    final totals = Analytics.totals(txs, from, end);
    final visible = txs.where((t) => !t.occurredAt.isBefore(from)).toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _BalanceCard(
            account: account,
            balance: data.balanceOf(account),
            currency: currency,
            totals: totals,
            periodName: periodLong[_period]!,
            onEdit: () => showSheet(context, AccountSheet(account: account)),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: VCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Segmented<Period>(
                  values: Period.values,
                  labels: [for (final p in Period.values) periodShort[p]!],
                  selected: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: BalanceChart(points: points, currency: currency, from: from, to: end),
              ),
            ]),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
          child: Row(children: [
            const Text('Movimenti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Muted(periodLong[_period]!),
          ]),
        ),
      ),
      if (visible.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Muted('Nessun movimento in questo periodo.', align: TextAlign.center),
          ),
        )
      else
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final t = visible[i];
            final newDay = i == 0 || !_sameDay(visible[i - 1].occurredAt, t.occurredAt);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (newDay)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, i == 0 ? 6 : 18, 20, 4),
                  child: Caption(dayTitle(t.occurredAt)),
                ),
              _TxnRow(txn: t, currency: currency, onTap: () => _openTxn(data, account, t)),
            ]);
          },
        ),
    ];
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ciao, ${data.username}',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Muted(longDate(DateTime.now())),
            ]),
          ),
          GestureDetector(
            onTap: () => AccountScreen.open(context),
            child: UserAvatar(name: data.username, photo: data.avatar, color: data.avatarColor, size: 46),
          ),
        ]),
      );
}

class _AccountStrip extends StatelessWidget {
  const _AccountStrip({required this.data, required this.accounts, required this.selectedId, required this.onSelect});

  final AppData data;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      margin: const EdgeInsets.only(bottom: 14),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final a in accounts) ...[
            _AccountChip(
              account: a,
              balance: data.balanceOf(a),
              selected: a.id == selectedId,
              onTap: () => onSelect(a.id),
            ),
            const SizedBox(width: 10),
          ],
          _NewAccountChip(onTap: () => showSheet(context, const AccountSheet())),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account, required this.balance, required this.selected, required this.onTap});

  final Account account;
  final int balance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 168,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1A2133) : VColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? VColors.accent : VColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(account.name,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(account.currency,
                    style: const TextStyle(color: VColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ]),
              const Spacer(),
              Text(
                Money.format(balance, currencyFor(account.currency)),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: balance < 0 ? VColors.negative : VColors.text,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NewAccountChip extends StatelessWidget {
  const _NewAccountChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 130,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VColors.borderStrong),
          ),
          child: const Text('+  Nuovo conto',
              style: TextStyle(color: VColors.accentLight, fontWeight: FontWeight.w600)),
        ),
      );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: VCard(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Text('Nessun conto, per ora', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Muted('Aggiungi un conto per iniziare a tenere traccia dei tuoi soldi.', align: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => showSheet(context, const AccountSheet()),
              child: const Text('Crea il tuo primo conto'),
            ),
          ]),
        ),
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.account,
    required this.balance,
    required this.currency,
    required this.totals,
    required this.periodName,
    required this.onEdit,
  });

  final Account account;
  final int balance;
  final Currency currency;
  final Totals totals;
  final String periodName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    String signed(String sign, int v) => (v != 0 ? sign : '') + Money.format(v, currency);
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Caption('Saldo attuale')),
          TextButton(onPressed: onEdit, child: const Text('Modifica')),
        ]),
        Text('${account.name}  ·  ${account.currency}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // Il saldo "conta" fino al nuovo valore.
        TweenAnimationBuilder<double>(
          tween: Tween(end: balance.toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(v.round(), currency),
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: v < 0 ? VColors.negative : VColors.text,
              ),
            ),
          ),
        ),
        Muted('Saldo iniziale: ${Money.format(account.initialBalance, currency)}'),
        const Divider(height: 26),
        Caption(periodName),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Muted('Entrate'),
              Text(signed('+', totals.income),
                  style: const TextStyle(color: VColors.positive, fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Muted('Uscite'),
              Text(signed('-', totals.expense),
                  style: const TextStyle(color: VColors.negative, fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.currency, required this.onTap});

  final Txn txn;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final income = txn.type == TxType.income;
    final tone = income ? VColors.positive : VColors.negative;
    final category = categoryFor(txn.categoryId)?.name ?? '—';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: tone.withValues(alpha: 0.14),
            child: Text(category.characters.first.toUpperCase(),
                style: TextStyle(color: tone, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final tag in txn.tags) TagPill(tag),
              ]),
              const SizedBox(height: 2),
              Muted(txn.description.isEmpty ? '—' : txn.description),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${income ? '+' : '-'}${Money.format(txn.amount, currency)}',
                style: TextStyle(color: tone, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Muted(timeOf(txn.occurredAt), size: 12),
          ]),
        ]),
      ),
    );
  }
}
