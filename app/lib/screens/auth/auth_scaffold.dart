import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/palette.dart';

/// Shared layout for login and sign-up: a green banner with the wordmark,
/// and the form on a sheet below it.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Scaffold(
      backgroundColor: Palette.cedarDeep,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tally', style: AppText.display(34, color: Palette.gold, weight: FontWeight.w800)),
                          const SizedBox(height: 22),
                          Text(title, style: AppText.display(28, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(subtitle, style: TextStyle(color: fade(Colors.white, 0.75), fontSize: 15, height: 1.4)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction action;
  final VoidCallback? onSubmitted;
  final bool isNew;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.action = TextInputAction.done,
    this.onSubmitted,
    this.isNew = false,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.action,
      autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

String? validateEmail(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'That email doesn\'t look right';
  return null;
}

String? validateNewPassword(String? v) {
  final value = v ?? '';
  if (value.length < 8) return 'Use at least 8 characters';
  if (value.length > 128) return 'Use 128 characters or fewer';
  return null;
}
