import 'dart:ui' show FontFeature;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Filled line chart for a value series (speed, RPM, temperature …).
/// [xs] are arbitrary monotonic x values (e.g. seconds into the trip).
class SeriesChart extends StatelessWidget {
  final List<double> xs;
  final List<double> ys;
  final Color color;
  final String unit;
  final double height;
  final double? maxYHint;
  final String Function(double)? xLabel;
  final bool dark;

  const SeriesChart({
    super.key,
    required this.xs,
    required this.ys,
    required this.color,
    this.unit = '',
    this.height = 160,
    this.maxYHint,
    this.xLabel,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (ys.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Zu wenig Daten für eine Kurve',
              style: TextStyle(
                  color: dark ? Colors.white38 : AppTheme.muted, fontSize: 12)),
        ),
      );
    }

    final maxY = [
      ys.reduce((a, b) => a > b ? a : b),
      if (maxYHint != null) maxYHint!,
    ].reduce((a, b) => a > b ? a : b);
    final niceMax = maxY <= 0 ? 1.0 : maxY * 1.15;
    final gridColor = dark ? Colors.white12 : AppTheme.line;
    final textColor = dark ? Colors.white54 : AppTheme.muted;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: niceMax,
          minX: xs.first,
          maxX: xs.last,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceMax / 3,
            getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: niceMax / 3,
                getTitlesWidget: (v, meta) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: xLabel != null,
                reservedSize: 22,
                interval: (xs.last - xs.first) / 3 <= 0 ? 1 : (xs.last - xs.first) / 3,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(xLabel?.call(v) ?? '',
                      style: TextStyle(fontSize: 10, color: textColor)),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.ink.withValues(alpha: 0.9),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(0)} $unit',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < ys.length && i < xs.length; i++)
                  FlSpot(xs[i], ys[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar chart with categorical labels (km per week, trips per day …).
class LabelledBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String unit;
  final double height;

  const LabelledBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AppTheme.brand,
    this.unit = '',
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final niceMax = maxV <= 0 ? 1.0 : maxV * 1.2;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: niceMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceMax / 2,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: niceMax / 2,
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i],
                        style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.ink.withValues(alpha: 0.9),
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} $unit',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: color,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Circular gauge for the cockpit (speed, RPM).
class CockpitGauge extends StatelessWidget {
  final double? value;
  final double max;
  final String label;
  final String unit;
  final Color color;
  final double size;
  final int decimals;

  const CockpitGauge({
    super.key,
    required this.value,
    required this.max,
    required this.label,
    required this.unit,
    required this.color,
    this.size = 150,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final fraction = max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 350),
              builder: (_, f, __) => CircularProgressIndicator(
                value: f,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value != null ? v.toStringAsFixed(decimals) : '—',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.30,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(unit,
                  style: TextStyle(color: Colors.white54, fontSize: size * 0.085)),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: size * 0.09, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar for a 0..100 % value (throttle, fuel, load).
class MeterBar extends StatelessWidget {
  final String label;
  final double? percent;
  final Color color;
  final bool dark;
  final String? valueText;

  const MeterBar({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
    this.dark = false,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = dark ? Colors.white70 : AppTheme.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
            Text(
              valueText ?? (percent != null ? '${percent!.toStringAsFixed(0)} %' : '—'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : AppTheme.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ((percent ?? 0) / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: dark ? Colors.white12 : AppTheme.line,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}
