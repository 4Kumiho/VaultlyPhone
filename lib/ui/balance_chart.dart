import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/analytics.dart';
import '../core/models.dart';
import '../core/money.dart';
import 'theme.dart';

/// Grafico a gradini del saldo. Toccando si vede il saldo in quel momento.
class BalanceChart extends StatelessWidget {
  const BalanceChart({super.key, required this.points, required this.currency, required this.from, required this.to});

  final List<BalancePoint> points;
  final Currency currency;
  final DateTime from;
  final DateTime to;

  double _units(int amount) => amount / pow(10, currency.minorUnits);

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (final p in points) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), _units(p.balance)),
    ];
    final values = spots.map((s) => s.y);
    var lo = values.reduce(min);
    var hi = values.reduce(max);
    final pad = hi > lo ? (hi - lo) * 0.15 : max(hi.abs() * 0.1, 1.0);
    lo -= pad;
    hi += pad;
    final minX = from.millisecondsSinceEpoch.toDouble();
    final maxX = to.millisecondsSinceEpoch.toDouble();
    final span = to.difference(from);
    final timeFormat = span.inDays <= 2
        ? DateFormat('HH:mm', 'it')
        : span.inDays <= 90
            ? DateFormat('d MMM', 'it')
            : DateFormat('MMM yy', 'it');

    return LineChart(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: lo,
        maxY: hi,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (hi - lo) / 4,
          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF20242D), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: (hi - lo) / 4,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox()
                  : Text(NumberFormat.compact(locale: 'it').format(v),
                      style: const TextStyle(color: VColors.muted, fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (maxX - minX) / 3,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(timeFormat.format(DateTime.fromMillisecondsSinceEpoch(v.toInt())),
                          style: const TextStyle(color: VColors.muted, fontSize: 10)),
                    ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => VColors.control,
            getTooltipItems: (items) => [
              for (final i in items)
                LineTooltipItem(
                  '${Money.format((i.y * pow(10, currency.minorUnits)).round(), currency)}\n',
                  const TextStyle(fontWeight: FontWeight.w700, color: VColors.text),
                  children: [
                    TextSpan(
                      text: DateFormat('d MMM, HH:mm', 'it').format(DateTime.fromMillisecondsSinceEpoch(i.x.toInt())),
                      style: const TextStyle(fontWeight: FontWeight.w400, color: VColors.muted, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: VColors.accent,
            barWidth: 2.5,
            isStepLineChart: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [VColors.accent.withValues(alpha: 0.35), VColors.accent.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
