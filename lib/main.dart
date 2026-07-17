import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/passcode_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/vault_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final VaultService _vaultService = VaultService();
  bool _isLoading = true;
  bool _unlocked = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVault();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Automatically lock the vault when the app goes into the background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _vaultService.lock();
      _vaultService.cleanTempFolder(); // Secure clean up of any open temp decrypted files
      setState(() {
        _unlocked = false;
      });
    }
  }

  Future<void> _initVault() async {
    try {
      if (kIsWeb) {
        throw UnsupportedError(
            'Local file encryption and file system storage are not supported in the web browser sandbox. '
            'Please run the app as a native Windows desktop app (flutter run -d windows) for secure local vault access.');
      }
      await _vaultService.init();
      setState(() {
        _isLoading = false;
        _unlocked = _vaultService.isUnlocked;
        _initError = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _initError = e.toString();
      });
    }
  }

  void _onUnlockSuccess() {
    setState(() {
      _unlocked = true;
    });
  }

  void _onLock() {
    setState(() {
      _unlocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;

    if (_isLoading) {
      homeScreen = const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 64, color: Colors.blueAccent),
              SizedBox(height: 16),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ],
          ),
        ),
      );
    } else if (_initError != null) {
      homeScreen = Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.amberAccent),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _initError!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!kIsWeb)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _initError = null;
                      });
                      _initVault();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } else if (!_unlocked) {
      homeScreen = PasscodeScreen(onSuccess: _onUnlockSuccess);
    } else {
      homeScreen = DashboardScreen(onLock: _onLock);
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MainApp.themeNotifier,
      builder: (_, ThemeMode currentMode, _2) {
        return MaterialApp(
          title: 'Secure Document Vault',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: Colors.black,
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              secondary: Colors.black54,
              surface: Color(0xFFF5F5F5),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: Colors.white,
            scaffoldBackgroundColor: const Color(0xFF000000),
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              secondary: Colors.white70,
              surface: Color(0xFF0F0F0F),
            ),
          ),
          home: homeScreen,
        );
      },
    );
  }
}
