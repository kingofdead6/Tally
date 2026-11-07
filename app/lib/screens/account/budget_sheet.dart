import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../state/auth_state.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

Future<void> showBudgetSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _BudgetSheet(),
  );
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet();

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _ctrl;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = context.read<AuthState>().user?.monthlyBudget ?? 0;
    _ctrl = TextEditingController(
      text: current > 0 ? Money.format(current, currency: false).replaceAll(' ', ' ') : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(double value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().updateProfile(monthlyBudget: value);
      if (!mounted) return;
      await context.read<FinanceState>().loadAll();
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, value == 0 ? 'Budget removed' : 'Budget saved');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBudget = (context.read<AuthState>().user?.monthlyBudget ?? 0) > 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Monthly budget', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('The most you want to spend each month. Home shows how much is left.'),
          const SizedBox(height: 18),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ,.]'))],
            decoration: InputDecoration(labelText: 'Amount', suffixText: 'DA', errorText: _error),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy
                ? null
                : () {
                    final v = Money.parse(_ctrl.text);
                    if (v == null || v <= 0) {
                      setState(() => _error = 'Enter an amount, like 30000');
                      return;
                    }
                    _save(v);
                  },
            child: const Text('Save budget'),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : () => _save(0), child: const Text('Remove budget')),
          ],
        ],
      ),
    );
  }
}
