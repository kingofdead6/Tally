import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../models/models.dart';
import '../../state/finance_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  Future<void> _delete(BuildContext context, Wallet w) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${w.name}"?',
      message: 'You can only delete a wallet with no transactions in it.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<FinanceState>().deleteWallet(w.id);
      if (context.mounted) showSnack(context, 'Wallet deleted');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final finance = context.watch<FinanceState>();
    final total = finance.wallets.fold<double>(0, (s, w) => s + w.balance);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWalletSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New wallet'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          Text(
            'Keep cash, your CCP card, a bank account or BaridiMob apart, so you always know what is where.',
            style: TextStyle(color: t.textSoft, height: 1.4),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Row(
              children: [
                Expanded(child: Text('All wallets', style: TextStyle(color: t.textSoft))),
                Text(Money.format(total), style: AppText.money(20, color: t.text)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (final w in finance.wallets)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: IconBadge(icon: w.icon, color: w.color, size: 40),
                    title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Started with ${Money.format(w.initialBalance)}'),
                    onTap: () => showWalletSheet(context, existing: w),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Money.format(w.balance),
                            style: AppText.money(15, color: w.balance < 0 ? t.expense : t.text)),
                        IconButton(
                          tooltip: 'Delete ${w.name}',
                          icon: Icon(Icons.delete_outline_rounded, color: t.textSoft),
                          onPressed: () => _delete(context, w),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showWalletSheet(BuildContext context, {Wallet? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WalletSheet(existing: existing),
  );
}

class _WalletSheet extends StatefulWidget {
  final Wallet? existing;
  const _WalletSheet({this.existing});

  @override
  State<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<_WalletSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _initial = TextEditingController(
    text: widget.existing == null || widget.existing!.initialBalance == 0
        ? ''
        : Money.format(widget.existing!.initialBalance.abs(), currency: false).replaceAll(' ', ' '),
  );
  late bool _negative = (widget.existing?.initialBalance ?? 0) < 0;
  late String _icon = widget.existing?.icon ?? 'card';
  late String _color = widget.existing?.color ?? Palette.swatches[4];
  bool _busy = false;
  String? _nameError;
  String? _amountError;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final raw = _initial.text.trim();
    final amount = raw.isEmpty ? 0.0 : Money.parse(raw);
    setState(() {
      _nameError = name.isEmpty ? 'Give it a name' : null;
      _amountError = amount == null ? 'Enter a number, like 5000' : null;
    });
    if (_nameError != null || _amountError != null) return;

    setState(() => _busy = true);
    try {
      await context.read<FinanceState>().saveWallet(
            id: widget.existing?.id,
            name: name,
            icon: _icon,
            color: _color,
            initial: _negative ? -amount! : amount!,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New wallet' : 'Edit wallet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                IconBadge(icon: _icon, color: _color, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. CCP, BaridiMob',
                      counterText: '',
                      errorText: _nameError,
                    ),
                  ),
                ),
              ],
            ),
            const FieldLabel('Starting balance'),
            TextField(
              controller: _initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'DA',
                errorText: _amountError,
                helperText: 'What was already in it before you started using Tally.',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _negative,
              onChanged: (v) => setState(() => _negative = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: t.expense,
              title: const Text('It started in debt (negative)'),
            ),
            const FieldLabel('Icon'),
            IconPicker(
              keys: AppIcons.walletKeys,
              selected: _icon,
              color: hexColor(_color),
              onSelect: (k) => setState(() => _icon = k),
            ),
            const FieldLabel('Colour'),
            ColorPicker(selected: _color, onSelect: (c) => setState(() => _color = c)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.existing == null ? 'Add wallet' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
