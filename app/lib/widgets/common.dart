import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_icons.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Round tinted badge with a category / wallet icon.
class IconBadge extends StatelessWidget {
  final String icon;
  final String color;
  final double size;
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = hexColor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fade(c, 0.15), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(AppIcons.of(icon), color: c, size: size * 0.5),
    );
  }
}

/// Amount coloured and signed by type.
class AmountText extends StatelessWidget {
  final double amount;
  final bool income;
  final double size;
  const AmountText({super.key, required this.amount, required this.income, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Text(
      Money.format(amount, withSign: true, income: income),
      style: AppText.money(size, color: income ? t.income : t.expense, weight: FontWeight.w700),
    );
  }
}

class TxnTile extends StatelessWidget {
  final Txn txn;
  final VoidCallback? onTap;
  final bool showDate;
  const TxnTile({super.key, required this.txn, this.onTap, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final subtitle = [
      if (txn.note.isNotEmpty) txn.note else (txn.isIncome ? 'Received' : 'Spent'),
      if (showDate) Dates.dayHeader(txn.date),
    ].join(', ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            IconBadge(icon: txn.category.icon, color: txn.category.color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: t.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.textSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(amount: txn.amount, income: txn.isIncome),
                const SizedBox(height: 4),
                Text(txn.wallet.name, style: TextStyle(fontSize: 12, color: t.textSoft)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-way switch between money in and money out.
class TypeToggle extends StatelessWidget {
  final TxType value;
  final ValueChanged<TxType> onChanged;
  final String incomeLabel;
  final String expenseLabel;

  const TypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.incomeLabel = 'Money in',
    this.expenseLabel = 'Money out',
  });

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    Widget seg(TxType type, String label, IconData icon) {
      final selected = value == type;
      final color = type == TxType.income ? t.income : t.expense;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: selected ? Colors.white : t.textSoft),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : t.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          seg(TxType.income, incomeLabel, Icons.south_west_rounded),
          const SizedBox(width: 4),
          seg(TxType.expense, expenseLabel, Icons.north_east_rounded),
        ],
      ),
    );
  }
}

/// Plain surface block used to group content.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: fade(t.brand, 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: t.brand, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: t.textSoft, height: 1.4)),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Try again.';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final t = Tones.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: destructive ? t.expense : t.brand),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Icon grid used when creating categories and wallets.
class IconPicker extends StatelessWidget {
  final List<String> keys;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelect;
  const IconPicker({super.key, required this.keys, required this.selected, required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final k in keys)
          Semantics(
            label: k,
            selected: k == selected,
            button: true,
            child: InkWell(
              onTap: () => onSelect(k),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: k == selected ? fade(color, 0.18) : t.sheet,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: k == selected ? color : t.line, width: k == selected ? 1.6 : 1),
                ),
                child: Icon(AppIcons.of(k), color: k == selected ? color : t.textSoft, size: 22),
              ),
            ),
          ),
      ],
    );
  }
}

class ColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const ColorPicker({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in Palette.swatches)
          Semantics(
            label: 'Colour $hex',
            selected: hex.toUpperCase() == selected.toUpperCase(),
            button: true,
            child: GestureDetector(
              onTap: () => onSelect(hex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hexColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hex.toUpperCase() == selected.toUpperCase() ? t.text : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: hex.toUpperCase() == selected.toUpperCase()
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Small label above a form field.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 18),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: Tones.of(context).textSoft)),
      );
}
