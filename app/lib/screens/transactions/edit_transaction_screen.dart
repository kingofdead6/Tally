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
import '../account/categories_screen.dart';

Future<void> openTransactionEditor(BuildContext context, {TxType type = TxType.expense, Txn? existing}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EditTransactionScreen(initialType: existing?.type ?? type, existing: existing),
    ),
  );
}

class EditTransactionScreen extends StatefulWidget {
  final TxType initialType;
  final Txn? existing;
  const EditTransactionScreen({super.key, required this.initialType, this.existing});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TxType _type;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _categoryId;
  String? _walletId;
  late DateTime _date;
  bool _busy = false;
  String? _amountError;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = widget.initialType;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _amount.text = Money.format(e.amount, currency: false).replaceAll(' ', ' ');
      _note.text = e.note;
      _categoryId = e.category.id;
      _walletId = e.wallet.id;
    }
    final finance = context.read<FinanceState>();
    _walletId ??= finance.wallets.isNotEmpty ? finance.wallets.first.id : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _switchType(TxType next) {
    if (next == _type) return;
    setState(() {
      _type = next;
      _categoryId = null; // categories differ between in and out
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final amount = Money.parse(_amount.text);
    setState(() => _amountError = null);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Enter an amount, like 1500 or 1500,50');
      return;
    }
    if (amount > 1000000000) {
      setState(() => _amountError = 'That amount is too large');
      return;
    }
    if (_categoryId == null) {
      showSnack(context, _type == TxType.income ? 'Pick where the money came from' : 'Pick what you spent it on');
      return;
    }
    if (_walletId == null) {
      showSnack(context, 'Pick a wallet');
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<FinanceState>().saveTransaction(
            id: widget.existing?.id,
            type: _type,
            amount: amount,
            category: _categoryId!,
            wallet: _walletId!,
            note: _note.text.trim(),
            date: _date,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, _editing ? 'Changes saved' : (_type == TxType.income ? 'Money in saved' : 'Money out saved'));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this transaction?',
      message: 'It will be removed from your history and balances. This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<FinanceState>().deleteTransaction(widget.existing!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Transaction deleted');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceState>();
    final t = Tones.of(context);
    final accent = _type == TxType.income ? t.income : t.expense;
    final categories = finance.categoriesOf(_type);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit transaction' : 'New transaction'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _busy ? null : _delete,
              icon: Icon(Icons.delete_outline_rounded, color: t.expense),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  TypeToggle(value: _type, onChanged: _switchType),
                  const SizedBox(height: 26),
                  // Amount
                  Center(
                    child: Text(
                      _type == TxType.income ? 'How much did you get?' : 'How much did you spend?',
                      style: TextStyle(color: t.textSoft),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amount,
                    autofocus: !_editing,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    style: AppText.money(44, color: accent, weight: FontWeight.w800),
                    cursorColor: accent,
                    onChanged: (_) {
                      if (_amountError != null) setState(() => _amountError = null);
                    },
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: AppText.money(44, color: fade(accent, 0.35), weight: FontWeight.w800),
                      suffixText: 'DA',
                      suffixStyle: AppText.money(22, color: accent, weight: FontWeight.w600),
                      filled: false,
                      errorText: _amountError,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                  Container(height: 2, color: fade(accent, 0.35)),

                  // Category / source
                  Row(
                    children: [
                      Expanded(child: FieldLabel(_type == TxType.income ? 'Where it came from' : 'What it was for')),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CategoriesScreen(initialType: _type)),
                          ),
                          child: const Text('Edit list'),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories)
                        _ChoiceChip(
                          label: c.name,
                          icon: c.icon,
                          color: c.color,
                          selected: c.id == _categoryId,
                          onTap: () => setState(() => _categoryId = c.id),
                        ),
                    ],
                  ),

                  // Wallet
                  FieldLabel(_type == TxType.income ? 'Into which wallet' : 'From which wallet'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in finance.wallets)
                        _ChoiceChip(
                          label: w.name,
                          icon: w.icon,
                          color: w.color,
                          selected: w.id == _walletId,
                          onTap: () => setState(() => _walletId = w.id),
                        ),
                    ],
                  ),

                  // Date
                  const FieldLabel('Date'),
                  Material(
                    color: t.sheet,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.line),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_rounded, color: t.textSoft),
                            const SizedBox(width: 12),
                            Expanded(child: Text(Dates.dayHeader(_date), style: TextStyle(color: t.text))),
                            Text('Change', style: TextStyle(color: t.brand, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Note
                  const FieldLabel('Note (optional)'),
                  TextField(
                    controller: _note,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _type == TxType.income ? 'e.g. Website for a client' : 'e.g. Lunch with friends',
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                child: _busy
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_editing ? 'Save changes' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final String icon;
  final String color;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final c = hexColor(color);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          decoration: BoxDecoration(
            color: selected ? fade(c, 0.16) : t.sheet,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? c : t.line, width: selected ? 1.6 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? c : fade(c, 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(AppIcons.of(icon), size: 16, color: selected ? Colors.white : c),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: t.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
