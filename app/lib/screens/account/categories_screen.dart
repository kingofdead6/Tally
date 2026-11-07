import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../models/models.dart';
import '../../state/finance_state.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';

class CategoriesScreen extends StatefulWidget {
  final TxType initialType;
  const CategoriesScreen({super.key, this.initialType = TxType.expense});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late TxType _type = widget.initialType;

  Future<void> _delete(TxCategory c) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${c.name}"?',
      message: 'You can only delete it if no transactions use it.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<FinanceState>().deleteCategory(c.id);
      if (mounted) showSnack(context, 'Category deleted');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final list = context.watch<FinanceState>().categoriesOf(_type);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategorySheet(context, type: _type),
        icon: const Icon(Icons.add_rounded),
        label: Text(_type == TxType.income ? 'New source' : 'New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          TypeToggle(
            value: _type,
            incomeLabel: 'Income sources',
            expenseLabel: 'Spending',
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (final c in list)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: IconBadge(icon: c.icon, color: c.color, size: 40),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => showCategorySheet(context, type: _type, existing: c),
                    trailing: IconButton(
                      tooltip: 'Delete ${c.name}',
                      icon: Icon(Icons.delete_outline_rounded, color: t.textSoft),
                      onPressed: () => _delete(c),
                    ),
                  ),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    message: 'Add one with the button below.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCategorySheet(BuildContext context, {required TxType type, TxCategory? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CategorySheet(type: type, existing: existing),
  );
}

class _CategorySheet extends StatefulWidget {
  final TxType type;
  final TxCategory? existing;
  const _CategorySheet({required this.type, this.existing});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? (widget.type == TxType.income ? 'salary' : 'food');
  late String _color = widget.existing?.color ?? Palette.swatches[3];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<FinanceState>().saveCategory(
            id: widget.existing?.id,
            name: name,
            type: widget.type,
            icon: _icon,
            color: _color,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.type == TxType.income ? AppIcons.incomeKeys : AppIcons.expenseKeys;
    final isIncome = widget.type == TxType.income;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing != null
                  ? 'Edit ${isIncome ? 'source' : 'category'}'
                  : (isIncome ? 'New income source' : 'New spending category'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconBadge(icon: _icon, color: _color, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: isIncome ? 'e.g. Freelance' : 'e.g. Coffee',
                      counterText: '',
                      errorText: _error,
                    ),
                  ),
                ),
              ],
            ),
            const FieldLabel('Icon'),
            IconPicker(keys: keys, selected: _icon, color: hexColor(_color), onSelect: (k) => setState(() => _icon = k)),
            const FieldLabel('Colour'),
            ColorPicker(selected: _color, onSelect: (c) => setState(() => _color = c)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.existing != null ? 'Save changes' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
