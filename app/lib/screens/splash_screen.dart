import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

class SplashScreen extends StatelessWidget {
  final bool offline;
  final VoidCallback? onRetry;
  const SplashScreen({super.key, this.offline = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.cedarDeep,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tally', style: AppText.display(52, color: Colors.white, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Every dinar in, every dinar out.',
                  style: TextStyle(color: fade(Colors.white, 0.72), fontSize: 15),
                ),
                const SizedBox(height: 36),
                if (!offline)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Palette.gold),
                  )
                else ...[
                  Text(
                    "Can't reach the server. Check your connection.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fade(Colors.white, 0.85)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.gold,
                      foregroundColor: Palette.ink,
                      minimumSize: const Size(160, 50),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
