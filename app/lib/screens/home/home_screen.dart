import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../models/models.dart';
import '../../state/auth_state.dart';
import '../../state/finance_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/banknote_card.dart';
import '../../widgets/common.dart';
import '../account/budget_sheet.dart';
import '../account/wallets_screen.dart';
import '../transactions/edit_transaction_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAll;
  const HomeScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceState>();
    final user = context.watch<AuthState>().user;
    final t = Tones.of(context);

    if (!finance.loaded && finance.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!finance.loaded && finance.error != null) {
      return SafeArea(
        child: Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your money",
            message: finance.error!,
            actionLabel: 'Try again',
            onAction: finance.loadAll,
          ),
        ),
      );
    }

    final now = DateTime.now();
    final m = finance.month;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: finance.loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, ${user?.firstName ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(Dates.month(now), style: TextStyle(color: t.textSoft)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            BanknoteCard(
              balance: m.balance,
              monthIn: m.income,
              monthOut: m.expense,
              monthLabel: 'This month',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    label: 'Money in',
                    icon: Icons.south_west_rounded,
                    color: t.income,
                    onTap: () => openTransactionEditor(context, type: TxType.income),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    label: 'Money out',
                    icon: Icons.north_east_rounded,
                    color: t.expense,
                    onTap: () => openTransactionEditor(context, type: TxType.expense),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BudgetPanel(budget: m.monthlyBudget, spent: m.spentThisMonth),
            const SizedBox(height: 22),
            SectionTitle(
              'Wallets',
              action: 'Manage',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletsScreen())),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: finance.wallets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _WalletChip(wallet: finance.wallets[i]),
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle('Recent', action: finance.recent.isEmpty ? null : 'See all', onAction: onSeeAll),
            if (finance.recent.isEmpty)
              Panel(
                child: EmptyState(
                  icon: Icons.edit_note_rounded,
                  title: 'Nothing recorded yet',
                  message: 'Add the money you received or spent today to start your history.',
                  actionLabel: 'Add your first one',
                  onAction: () => openTransactionEditor(context, type: TxType.expense),
                ),
              )
            else
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    for (final tx in finance.recent)
                      TxnTile(
                        txn: tx,
                        showDate: true,
                        onTap: () => openTransactionEditor(context, existing: tx),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Material(
      color: t.sheet,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: t.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetPanel extends StatelessWidget {
  final double budget;
  final double spent;
  const _BudgetPanel({required this.budget, required this.spent});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    if (budget <= 0) {
      return Panel(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: Palette.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Set a monthly limit to see how much is left.', style: TextStyle(color: t.textSoft)),
            ),
            TextButton(onPressed: () => showBudgetSheet(context), child: const Text('Set budget')),
          ],
        ),
      );
    }

    final ratio = (spent / budget).clamp(0.0, 1.0);
    final left = budget - spent;
    final over = left < 0;
    final barColor = over ? t.expense : (ratio > 0.8 ? Palette.gold : t.brand);

    return Panel(
      child: InkWell(
        onTap: () => showBudgetSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(over ? 'Over budget by' : 'Left to spend this month',
                          style: TextStyle(color: t.textSoft, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(Money.format(left.abs()),
                          style: AppText.money(22, color: over ? t.expense : t.text)),
                    ],
                  ),
                ),
                Text('of ${Money.format(budget)}', style: TextStyle(color: t.textSoft, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: t.line,
                color: barColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  final Wallet wallet;
  const _WalletChip({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconBadge(icon: wallet.icon, color: wallet.color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textSoft, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(wallet.balance),
              style: AppText.money(17, color: wallet.balance < 0 ? t.expense : t.text),
            ),
          ),
        ],
      ),
    );
  }
}
