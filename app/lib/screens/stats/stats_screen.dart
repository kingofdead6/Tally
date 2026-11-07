import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../state/finance_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  TxType _breakdownType = TxType.expense;

  MoneySummary? _summary;
  double _breakdownTotal = 0;
  List<CategoryShare> _shares = [];
  List<MonthPoint> _trend = [];
  bool _loading = true;
  String? _error;
  int _seenRevision = -1;
  int _requestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rev = context.watch<FinanceState>().revision;
    if (rev != _seenRevision) {
      _seenRevision = rev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<Repository>();
      final from = Dates.startOfMonth(_month);
      final to = Dates.endOfMonth(_month);
      final results = await Future.wait([
        repo.summary(from: from, to: to),
        repo.byCategory(_breakdownType, from: from, to: to),
        repo.trend(months: 6),
      ]);
      if (!mounted || id != _requestId) return;
      final breakdown = results[1] as (double, List<CategoryShare>);
      setState(() {
        _summary = results[0] as MoneySummary;
        _breakdownTotal = breakdown.$1;
        _shares = breakdown.$2;
        _trend = results[2] as List<MonthPoint>;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = errorText(e));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final now = DateTime.now();
    final atCurrent = _month.year == now.year && _month.month == now.month;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text('Stats', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    Dates.month(_month),
                    textAlign: TextAlign.center,
                    style: AppText.display(18, color: t.text, weight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: atCurrent ? null : () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null && _summary == null)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load stats",
                message: _error!,
                actionLabel: 'Try again',
                onAction: _load,
              )
            else if (_summary == null)
              const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
            else ...[
              AnimatedOpacity(
                opacity: _loading ? 0.55 : 1,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Totals(summary: _summary!),
                    const SizedBox(height: 20),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TypeToggle(
                            value: _breakdownType,
                            incomeLabel: 'Sources',
                            expenseLabel: 'Spending',
                            onChanged: (v) {
                              setState(() => _breakdownType = v);
                              _load();
                            },
                          ),
                          const SizedBox(height: 20),
                          _Breakdown(type: _breakdownType, total: _breakdownTotal, shares: _shares),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last 6 months', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _LegendDot(color: t.income, label: 'In'),
                              const SizedBox(width: 14),
                              _LegendDot(color: t.expense, label: 'Out'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(height: 210, child: _TrendChart(points: _trend)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final MoneySummary summary;
  const _Totals({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    Widget cell(String label, double value, Color color, {bool signed = false}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: t.textSoft, fontSize: 13)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  signed ? Money.format(value, withSign: true, income: value >= 0) : Money.format(value),
                  style: AppText.money(18, color: color),
                ),
              ),
            ],
          ),
        );

    return Panel(
      child: Row(
        children: [
          cell('Money in', summary.income, t.income),
          cell('Money out', summary.expense, t.expense),
          cell('Kept', summary.net, summary.net >= 0 ? t.text : t.expense, signed: true),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final TxType type;
  final double total;
  final List<CategoryShare> shares;
  const _Breakdown({required this.type, required this.total, required this.shares});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    if (shares.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          type == TxType.expense ? 'No spending recorded this month.' : 'No money received this month.',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSoft),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: 64,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final s in shares)
                      PieChartSectionData(
                        value: s.total,
                        color: hexColor(s.color),
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type == TxType.expense ? 'Spent' : 'Received', style: TextStyle(color: t.textSoft, fontSize: 13)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 110,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(Money.format(total), style: AppText.money(18, color: t.text)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                IconBadge(icon: s.icon, color: s.color, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Text(Money.format(s.total), style: AppText.money(14, color: t.text, weight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (s.percent / 100).clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: t.line,
                                color: hexColor(s.color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${s.percent.toStringAsFixed(s.percent >= 10 ? 0 : 1).replaceAll('.', ',')}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 12, color: t.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Tones.of(context).textSoft, fontSize: 13)),
        ],
      );
}

class _TrendChart extends StatelessWidget {
  final List<MonthPoint> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    if (points.isEmpty) return const SizedBox.shrink();

    final peak = points.fold<double>(0, (m, p) => math.max(m, math.max(p.income, p.expense)));
    final interval = _niceInterval(peak);
    final maxY = peak <= 0 ? interval * 4 : (peak / interval).ceil() * interval;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(color: t.line, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  Money.compact(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: t.textSoft),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(Dates.monthShort(points[i].date), style: TextStyle(fontSize: 12, color: t.textSoft)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: points[i].income,
                  color: t.income,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: points[i].expense,
                  color: t.expense,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 1, 2 or 5 × a power of ten, giving roughly four grid lines.
  static double _niceInterval(double peak) {
    if (peak <= 0) return 1000;
    final raw = peak / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final step = norm <= 1 ? 1 : (norm <= 2 ? 2 : (norm <= 5 ? 5 : 10));
    return step * mag;
  }
}
