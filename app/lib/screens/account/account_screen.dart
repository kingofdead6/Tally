import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../models/models.dart';
import '../../state/auth_state.dart';
import '../../state/finance_state.dart';
import '../../state/theme_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';
import '../auth/auth_scaffold.dart';
import 'budget_sheet.dart';
import 'categories_screen.dart';
import 'wallets_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final finance = context.watch<FinanceState>();
    final mode = context.watch<ThemeState>().mode;

    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text('Account', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          Panel(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Palette.cedar, shape: BoxShape.circle),
                  child: Text(user?.initials ?? '?', style: AppText.display(21, color: Palette.gold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '', style: TextStyle(color: t.textSoft)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit name',
                  icon: Icon(Icons.edit_outlined, color: t.textSoft),
                  onPressed: () => _editName(context, user?.name ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Group(children: [
            _Row(
              icon: Icons.flag_outlined,
              title: 'Monthly budget',
              value: (user?.monthlyBudget ?? 0) > 0 ? Money.format(user!.monthlyBudget) : 'Not set',
              onTap: () => showBudgetSheet(context),
            ),
            _Row(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallets',
              value: '${finance.wallets.length}',
              onTap: () => push(const WalletsScreen()),
            ),
            _Row(
              icon: Icons.south_west_rounded,
              title: 'Income sources',
              value: '${finance.categoriesOf(TxType.income).length}',
              onTap: () => push(const CategoriesScreen(initialType: TxType.income)),
            ),
            _Row(
              icon: Icons.north_east_rounded,
              title: 'Spending categories',
              value: '${finance.categoriesOf(TxType.expense).length}',
              onTap: () => push(const CategoriesScreen(initialType: TxType.expense)),
            ),
          ]),
          const SizedBox(height: 18),
          _Group(children: [
            _Row(
              icon: Icons.dark_mode_outlined,
              title: 'Appearance',
              value: switch (mode) { ThemeMode.light => 'Light', ThemeMode.dark => 'Dark', _ => 'Automatic' },
              onTap: () => _pickTheme(context, mode),
            ),
            _Row(
              icon: Icons.lock_outline_rounded,
              title: 'Change password',
              onTap: () => push(const ChangePasswordScreen()),
            ),
          ]),
          const SizedBox(height: 18),
          _Group(children: [
            _Row(
              icon: Icons.logout_rounded,
              title: 'Log out',
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Log out?',
                  message: 'Your data stays saved. Log in again to see it.',
                  confirmLabel: 'Log out',
                  destructive: false,
                );
                if (ok && context.mounted) await context.read<AuthState>().logout();
              },
            ),
            _Row(
              icon: Icons.delete_forever_outlined,
              title: 'Delete account',
              danger: true,
              onTap: () => _deleteAccount(context),
            ),
          ]),
          const SizedBox(height: 24),
          Center(child: Text('Tally 1.0', style: TextStyle(color: t.textSoft, fontSize: 12))),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || name == current || !context.mounted) return;
    try {
      await context.read<AuthState>().updateProfile(name: name);
      if (context.mounted) showSnack(context, 'Name saved');
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  Future<void> _pickTheme(BuildContext context, ThemeMode current) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, label) in [
              (ThemeMode.system, 'Automatic (follow phone)'),
              (ThemeMode.light, 'Light'),
              (ThemeMode.dark, 'Dark'),
            ])
              ListTile(
                title: Text(label),
                trailing: mode == current ? Icon(Icons.check_rounded, color: Tones.of(ctx).brand) : null,
                onTap: () => Navigator.pop(ctx, mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) await context.read<ThemeState>().set(picked);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ctrl = TextEditingController();
    final t = Tones.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This permanently deletes your account, wallets, categories and every transaction. '
                'It can\'t be undone.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Enter your password to confirm'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: TextButton.styleFrom(foregroundColor: t.expense),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (password == null || password.isEmpty || !context.mounted) return;
    try {
      await context.read<AuthState>().deleteAccount(password);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: t.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool danger;
  const _Row({required this.icon, required this.title, required this.onTap, this.value, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final color = danger ? t.expense : t.text;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? t.expense : t.textSoft),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: TextStyle(color: t.textSoft)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: t.textSoft),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Password changed. Other devices were logged out.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PasswordField(
              controller: _current,
              label: 'Current password',
              action: TextInputAction.next,
              validator: (v) => (v ?? '').isEmpty ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _next,
              label: 'New password',
              isNew: true,
              action: TextInputAction.next,
              validator: validateNewPassword,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              isNew: true,
              onSubmitted: _submit,
              validator: (v) => v != _next.text ? 'Passwords don\'t match' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}
