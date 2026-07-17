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

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final VaultService _vaultService = VaultService();
  bool _isLoading = true;
  bool _unlocked = false;

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
    await _vaultService.init();
    setState(() {
      _isLoading = false;
      _unlocked = _vaultService.isUnlocked;
    });
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
    } else if (!_unlocked) {
      homeScreen = PasscodeScreen(onSuccess: _onUnlockSuccess);
    } else {
      homeScreen = DashboardScreen(onLock: _onLock);
    }

    return MaterialApp(
      title: 'Secure Document Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
        ),
      ),
      home: homeScreen,
    );
  }
}
