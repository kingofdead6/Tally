import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/repository.dart';
import 'core/token_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/home_shell.dart';
import 'screens/splash_screen.dart';
import 'state/auth_state.dart';
import 'state/finance_state.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Falls back to the default API address in AppConfig.
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final storage = TokenStorage();
  final repo = Repository(ApiClient(storage));
  final theme = ThemeState(storage);
  await theme.load();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: repo),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider(create: (_) => AuthState(repo, storage)..bootstrap()),
        ChangeNotifierProvider(create: (_) => FinanceState(repo)),
      ],
      child: const TallyApp(),
    ),
  );
}

class TallyApp extends StatelessWidget {
  const TallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeState>().mode;
    return MaterialApp(
      title: 'Tally',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const RootGate(),
    );
  }
}

/// Shows the right screen for the current session state.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  AuthStatus? _last;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (auth.status != _last) {
      final previous = _last;
      _last = auth.status;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final finance = context.read<FinanceState>();
        if (auth.status == AuthStatus.signedIn) {
          finance.loadAll();
        } else if (previous == AuthStatus.signedIn) {
          finance.reset();
          // Drop any screens pushed on top of the shell.
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      });
    }

    final Widget child = switch (auth.status) {
      AuthStatus.checking => const SplashScreen(),
      AuthStatus.offline => SplashScreen(offline: true, onRetry: auth.bootstrap),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => const HomeShell(),
    };

    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: child);
  }
}
