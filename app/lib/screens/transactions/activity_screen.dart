import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/repository.dart';
import '../../models/models.dart';
import '../../state/finance_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import 'edit_transaction_screen.dart';

enum _Filter { all, income, expense }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  _Filter _filter = _Filter.all;
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month); // null = all time
  String? _categoryId;

  final List<Txn> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _seenRevision = -1;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rev = context.watch<FinanceState>().revision;
    if (rev != _seenRevision) {
      _seenRevision = rev;
      // Can't setState while dependencies are being resolved; run after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Starts again from page 1. Current items stay visible until new ones arrive.
  Future<void> _reload() async {
    _page = 1;
    _hasMore = true;
    await _fetch(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    await _fetch();
  }

  Future<void> _fetch({bool reset = false}) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final repo = context.read<Repository>();
      final page = await repo.transactions(
        type: switch (_filter) { _Filter.income => TxType.income, _Filter.expense => TxType.expense, _ => null },
        category: _categoryId,
        from: _month == null ? null : Dates.startOfMonth(_month!),
        to: _month == null ? null : Dates.endOfMonth(_month!),
        q: _search.text.trim(),
        page: _page,
      );
      if (!mounted || id != _requestId) return; // a newer request replaced this one
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _page += 1;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = errorText(e));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _shiftMonth(int delta) {
    final m = _month ?? DateTime(DateTime.now().year, DateTime.now().month);
    final next = DateTime(m.year, m.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _reload();
  }

  Future<bool> _confirmDelete(Txn tx) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this transaction?',
      message: '${tx.category.name}, ${Money.format(tx.amount)}. This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return false;
    try {
      await context.read<FinanceState>().deleteTransaction(tx.id);
      if (mounted) showSnack(context, 'Transaction deleted');
      return true;
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final finance = context.watch<FinanceState>();
    final now = DateTime.now();
    final atCurrentMonth = _month != null && _month!.year == now.year && _month!.month == now.month;

    // Group into days
    final groups = <DateTime, List<Txn>>{};
    for (final tx in _items) {
      final key = DateTime(tx.date.year, tx.date.month, tx.date.day);
      groups.putIfAbsent(key, () => []).add(tx);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final categoryChoices = switch (_filter) {
      _Filter.income => finance.categoriesOf(TxType.income),
      _Filter.expense => finance.categoriesOf(TxType.expense),
      _ => finance.categories,
    };

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text('Activity', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _reload();
                        },
                      ),
              ),
            ),
          ),
          // Month navigator
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _month = _month == null ? DateTime(now.year, now.month) : null);
                      _reload();
                    },
                    child: Column(
                      children: [
                        Text(
                          _month == null ? 'All time' : Dates.month(_month!),
                          textAlign: TextAlign.center,
                          style: AppText.display(17, color: t.text, weight: FontWeight.w600),
                        ),
                        Text(
                          _month == null ? 'Tap for this month' : 'Tap for all time',
                          style: TextStyle(fontSize: 12, color: t.textSoft),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: (_month == null || atCurrentMonth) ? null : () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          // Filters
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                _FilterPill(
                  label: 'All',
                  selected: _filter == _Filter.all,
                  onTap: () {
                    setState(() => _filter = _Filter.all);
                    _reload();
                  },
                ),
                _FilterPill(
                  label: 'Money in',
                  color: t.income,
                  selected: _filter == _Filter.income,
                  onTap: () {
                    setState(() {
                      _filter = _Filter.income;
                      _categoryId = null;
                    });
                    _reload();
                  },
                ),
                _FilterPill(
                  label: 'Money out',
                  color: t.expense,
                  selected: _filter == _Filter.expense,
                  onTap: () {
                    setState(() {
                      _filter = _Filter.expense;
                      _categoryId = null;
                    });
                    _reload();
                  },
                ),
                Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), color: t.line),
                for (final c in categoryChoices)
                  _FilterPill(
                    label: c.name,
                    color: hexColor(c.color),
                    selected: _categoryId == c.id,
                    onTap: () {
                      setState(() => _categoryId = _categoryId == c.id ? null : c.id);
                      _reload();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _buildList(days, groups, t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<DateTime> days, Map<DateTime, List<Txn>> groups, Tones t) {
    if (_items.isEmpty && _loading) {
      return ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())]);
    }
    if (_items.isEmpty && _error != null) {
      return ListView(children: [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load transactions",
          message: _error!,
          actionLabel: 'Try again',
          onAction: _reload,
        ),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(children: const [
        EmptyState(
          icon: Icons.inbox_rounded,
          title: 'No transactions here',
          message: 'Try another month or filter, or add one with the + button.',
        ),
      ]);
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: days.length + 1,
      itemBuilder: (context, i) {
        if (i == days.length) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : (_hasMore ? const SizedBox.shrink() : Text('That\'s everything', style: TextStyle(color: t.textSoft))),
            ),
          );
        }
        final day = days[i];
        final list = groups[day]!;
        final net = list.fold<double>(0, (sum, tx) => sum + tx.signed);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(Dates.dayHeader(day),
                        style: TextStyle(fontWeight: FontWeight.w700, color: t.textSoft)),
                  ),
                  Text(
                    Money.format(net, withSign: true, income: net >= 0),
                    style: AppText.money(13, color: t.textSoft, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                children: [
                  for (final tx in list)
                    Dismissible(
                      key: ValueKey(tx.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(tx),
                      onDismissed: (_) => setState(() => _items.removeWhere((x) => x.id == tx.id)),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 18),
                        decoration: BoxDecoration(
                          color: fade(t.expense, 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.delete_outline_rounded, color: t.expense),
                      ),
                      child: TxnTile(
                        txn: tx,
                        onTap: () => openTransactionEditor(context, existing: tx),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final c = color ?? t.brand;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c : t.sheet,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? c : t.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: selected ? Colors.white : t.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
