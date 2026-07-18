import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/passcode_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/vault_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final VaultService _vaultService = VaultService();
  bool _isLoading = true;
  bool _unlocked = false;
  bool _showOnboarding = true;
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
      if (_vaultService.isPickingFile) {
        // Skip locking when picking/exporting files via system picker
        return;
      }
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
        _showOnboarding = !_vaultService.hasPasscode;
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
      homeScreen = Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 64, height: 64),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
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
    } else if (_showOnboarding) {
      homeScreen = OnboardingScreen(
        onGetStarted: () {
          setState(() {
            _showOnboarding = false;
          });
        },
      );
    } else if (!_unlocked) {
      homeScreen = PasscodeScreen(onSuccess: _onUnlockSuccess);
    } else {
      homeScreen = DashboardScreen(onLock: _onLock);
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MainApp.themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Secure Document Vault',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF11161A),
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            cardColor: const Color(0xFFFFFFFF),
            dividerColor: const Color(0xFFE5E5E5),
            fontFamily: 'Inter',
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF11161A),
              secondary: Color(0xFF737A8C),
              tertiary: Color(0xFFBBBECA),
              surface: Color(0xFFFFFFFF),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFF9FAFD),
            scaffoldBackgroundColor: const Color(0xFF090D12),
            cardColor: const Color(0xFF151E2E),
            dividerColor: const Color(0xFF222222),
            fontFamily: 'Inter',
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF9FAFD),
              secondary: Color(0xFF969CB0),
              tertiary: Color(0xFFBBBECA),
              surface: Color(0xFF151E2E),
            ),
          ),
          home: homeScreen,
        );
      },
    );
  }
}
