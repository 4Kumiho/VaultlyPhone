import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/app_data.dart';
import '../core/models.dart';
import '../core/money.dart';
import 'format.dart';
import 'sheets/tag_detail_sheet.dart';
import 'sheets/tag_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sezione "Etichette": una tantum (tra due date) e ricorrenti (periodo in corso + precedente).
class TagsTab extends StatelessWidget {
  const TagsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final items = [for (final t in data.tags) (tag: t, status: data.budgetStatus(t))]
      ..sort((a, b) {
        final ua = _urgency(a.tag, a.status), ub = _urgency(b.tag, b.status);
        if (ua != ub) return ub.compareTo(ua);
        if (a.tag.budget != null && b.tag.budget != null) return b.status.ratio.compareTo(a.status.ratio);
        return b.status.spent.compareTo(a.status.spent);
      });
    final oneShot = items.where((i) => !i.tag.recurring).toList();
    final recurring = items.where((i) => i.tag.recurring).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSheet(context, const TagSheet()),
        icon: const Icon(Icons.add),
        label: const Text('Etichetta', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Etichette', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Muted('Una tantum: valgono tra due date, es. un viaggio. '
                  'Ricorrenti: ripartono ogni periodo, es. l\'autostrada di ogni mese, e ne tieni lo storico.'),
            ),
            if (items.isEmpty)
              const VCard(
                padding: EdgeInsets.all(24),
                child: Muted('Non hai ancora etichette. Creane una con "+ Etichetta".', align: TextAlign.center),
              ),
            if (recurring.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Caption('Ricorrenti')),
              for (final i in recurring) ...[
                _TagCard(tag: i.tag, status: i.status),
                const SizedBox(height: 10),
              ],
            ],
            if (oneShot.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(4, recurring.isEmpty ? 0 : 10, 4, 8),
                child: const Caption('Una tantum'),
              ),
              for (final i in oneShot) ...[
                _TagCard(tag: i.tag, status: i.status),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static int _urgency(Tag tag, BudgetStatus s) {
    if (s.finished) return -1; // concluse in fondo
    if (tag.budget == null || s.upcoming) return 0;
    return switch (s.level) { BudgetLevel.over => 3, BudgetLevel.warning => 2, _ => 1 };
  }
}

/// "Ogni mese · Settembre 2026" oppure "Una tantum · 3 – 10 ott".
String tagSubtitle(Tag tag, BudgetStatus s) => tag.recurring
    ? '${recurrenceLabel(tag.unit, tag.every)} · ${tagPeriodLabel(tag, s.from, s.to)}'
    : 'Una tantum · ${tagPeriodLabel(tag, s.from, s.to)}';

class _TagCard extends StatelessWidget {
  const _TagCard({required this.tag, required this.status});

  final Tag tag;
  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    final history = tag.recurring ? data.tagHistory(tag) : const <BudgetStatus>[];
    final previous = history.length > 1 ? history[1] : null;
    final currency = currencyFor(tag.currency);
    return VCard(
      onTap: () => showSheet(context, TagDetailSheet(tagId: tag.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TagPill(tag.name),
          const SizedBox(width: 8),
          Expanded(child: Muted(tagSubtitle(tag, status), size: 12)),
          const Icon(Icons.chevron_right, color: VColors.faint, size: 20),
        ]),
        const SizedBox(height: 12),
        BudgetSummary(tag: tag, status: status),
        if (previous != null) ...[
          const SizedBox(height: 8),
          Muted(
            '${tagPeriodLabel(tag, previous.from, previous.to)}: ${Money.format(previous.spent, currency)}',
            size: 12.5,
          ),
        ],
      ]),
    );
  }
}

/// Speso nel periodo, barra rispetto al tetto e stato ("restano...", "superato di...").
class BudgetSummary extends StatelessWidget {
  const BudgetSummary({super.key, required this.tag, required this.status});

  final Tag tag;
  final BudgetStatus status;

  static Color colorOf(BudgetLevel level) => switch (level) {
        BudgetLevel.over => VColors.negative,
        BudgetLevel.warning => VColors.warning,
        _ => VColors.positive,
      };

  String _statusText(Currency currency) {
    if (status.upcoming) return 'Inizia il ${shortDate(status.from)}';
    final spentCount = status.count == 1 ? '1 spesa' : '${status.count} spese';
    var text = switch (status.level) {
      BudgetLevel.noBudget => '$spentCount · nessun tetto di spesa',
      BudgetLevel.over => 'Tetto superato di ${Money.format(status.spent - status.budget, currency)}',
      BudgetLevel.warning => status.spent == status.budget
          ? 'Tetto raggiunto'
          : 'Quasi al limite · restano ${Money.format(status.budget - status.spent, currency)}',
      BudgetLevel.ok => 'Restano ${Money.format(status.budget - status.spent, currency)}',
    };
    if (!tag.recurring) {
      if (status.finished) {
        text = 'Conclusa il ${shortDate(status.to)} · ${text[0].toLowerCase()}${text.substring(1)}';
      } else {
        final today = DateTime.now();
        final days = DateTime.utc(status.to.year, status.to.month, status.to.day)
            .difference(DateTime.utc(today.year, today.month, today.day))
            .inDays;
        text += days == 0 ? ' · ultimo giorno' : days == 1 ? ' · manca 1 giorno' : ' · mancano $days giorni';
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final currency = currencyFor(tag.currency);
    final hasBudget = tag.budget != null;
    final color = colorOf(status.level);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(Money.format(status.spent, currency), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        if (hasBudget)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 2),
            child: Muted('di ${Money.format(status.budget, currency)}'),
          ),
      ]),
      if (hasBudget) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: status.ratio.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: status.spent > 0 ? v.clamp(0.02, 1).toDouble() : 0,
              minHeight: 7,
              color: color,
              backgroundColor: VColors.background,
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Text(_statusText(currency),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: !hasBudget || status.level == BudgetLevel.ok || status.upcoming
                ? VColors.muted
                : Color.lerp(color, Colors.white, 0.2),
          )),
    ]);
  }
}
