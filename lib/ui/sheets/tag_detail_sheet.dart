import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart';
import '../../core/app_data.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../format.dart';
import '../tags_tab.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tag_sheet.dart';

/// Scheda di un'etichetta: periodo in corso e, se ricorrente, storico dei periodi precedenti
/// (grafico e elenco, ogni periodo si apre per vederne le spese).
class TagDetailSheet extends StatelessWidget {
  const TagDetailSheet({super.key, required this.tagId});
  final String tagId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final tag = data.tags.where((t) => t.id == tagId).firstOrNull;
    if (tag == null) return const SizedBox(height: 120, child: Center(child: Muted('Etichetta eliminata.')));
    final history = data.tagHistory(tag);
    final current = history.first;
    final currency = currencyFor(tag.currency);
    final past = history.skip(1).toList();
    final average = past.isEmpty ? null : past.fold(0, (s, p) => s + p.spent) ~/ past.length;

    return SheetScaffold(
      title: tag.name,
      subtitle: tagSubtitle(tag, current),
      fields: [
        VCard(child: BudgetSummary(tag: tag, status: current)),
        if (tag.recurring) ...[
          const FieldLabel('Storico'),
          if (history.length < 2)
            const Muted('Qui vedrai i periodi precedenti, man mano che passano.')
          else ...[
            VCard(
              padding: const EdgeInsets.fromLTRB(8, 18, 14, 8),
              child: SizedBox(height: 170, child: _HistoryChart(tag: tag, history: history)),
            ),
            if (average != null) ...[
              const SizedBox(height: 8),
              Muted(
                'Media dei periodi precedenti: ${Money.format(average, currency)}'
                '${past.length == 1 ? '' : ' (${past.length} periodi)'}',
                size: 12.5,
              ),
            ],
          ],
          const SizedBox(height: 10),
          for (final s in history) _PeriodTile(tag: tag, status: s, current: identical(s, current)),
        ] else ...[
          const FieldLabel('Spese'),
          _Expenses(tag: tag, from: current.from, to: current.to),
        ],
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: () => showSheet(context, TagSheet(tag: tag)),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Modifica etichetta'),
        ),
      ],
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.tag, required this.history});
  final Tag tag;
  final List<BudgetStatus> history;

  @override
  Widget build(BuildContext context) {
    final shown = history.take(12).toList().reversed.toList(); // dal più vecchio
    final currency = currencyFor(tag.currency);
    final budget = tag.budget;
    final top = max(shown.map((s) => s.spent).fold(0, max), budget ?? 0);
    final maxY = top == 0 ? 1.0 : top * 1.15;
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= shown.length) return const SizedBox();
                // Con molte barre si scrive una data sì e una no.
                if (shown.length > 7 && (shown.length - 1 - i).isOdd) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(tagBarLabel(tag, shown[i].from), style: const TextStyle(fontSize: 10.5, color: VColors.muted)),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (budget != null)
            HorizontalLine(y: budget.toDouble(), color: VColors.warning.withValues(alpha: 0.7), strokeWidth: 1.2, dashArray: [5, 4]),
        ]),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => VColors.control,
            getTooltipItem: (group, _, _, _) {
              final s = shown[group.x];
              return BarTooltipItem(
                '${tagPeriodLabel(tag, s.from, s.to)}\n${Money.format(s.spent, currency)}',
                const TextStyle(color: VColors.text, fontSize: 12, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < shown.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: shown[i].spent.toDouble(),
                width: shown.length > 8 ? 12 : 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                color: budget == null
                    ? (i == shown.length - 1 ? VColors.accent : VColors.accent.withValues(alpha: 0.55))
                    : BudgetSummary.colorOf(shown[i].level)
                        .withValues(alpha: i == shown.length - 1 ? 1 : 0.6),
              ),
            ]),
        ],
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.tag, required this.status, required this.current});
  final Tag tag;
  final BudgetStatus status;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final currency = currencyFor(tag.currency);
    final color = tag.budget == null ? VColors.text : BudgetSummary.colorOf(status.level);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(tagPeriodLabel(tag, status.from, status.to) + (current ? ' · in corso' : ''),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Muted(status.count == 1 ? '1 spesa' : '${status.count} spese', size: 12),
        trailing: Text(Money.format(status.spent, currency), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        children: [_Expenses(tag: tag, from: status.from, to: status.to)],
      ),
    );
  }
}

class _Expenses extends StatelessWidget {
  const _Expenses({required this.tag, required this.from, required this.to});
  final Tag tag;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    final expenses = data.tagExpenses(tag, from, to);
    if (expenses.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Muted('Nessuna spesa.'));
    }
    return Column(children: [
      for (final t in expenses)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.description.isEmpty ? (categoryFor(t.categoryId)?.name ?? '—') : t.description,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Muted('${dayTitle(t.occurredAt)} · ${data.account(t.accountId)?.name ?? ''}', size: 12),
              ]),
            ),
            Text('-${Money.format(t.amount, currencyFor(data.account(t.accountId)?.currency ?? tag.currency))}',
                style: const TextStyle(color: VColors.negative, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }
}
