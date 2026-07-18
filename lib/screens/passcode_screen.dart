import 'package:flutter/material.dart';
import '../services/vault_service.dart';
import '../widgets/animated_background.dart';

class PasscodeScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const PasscodeScreen({super.key, required this.onSuccess});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  final VaultService _vaultService = VaultService();
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final hasPasscode = _vaultService.hasPasscode;
    final isBioEnabled = _vaultService.isBiometricEnabled;
    final canUseBio = await _vaultService.canUseBiometrics();

    setState(() {
      _canCheckBiometrics = hasPasscode && isBioEnabled && canUseBio;
    });

    if (_canCheckBiometrics) {
      // Auto-trigger biometric authentication on launch
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometrics();
      });
    }
  }

  Future<void> _triggerBiometrics() async {
    final success = await _vaultService.authenticateWithBiometrics();
    if (success) {
      widget.onSuccess();
    }
  }

  void _onKeyPress(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _errorMessage = '';
    });

    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _processPin);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = '';
    });
  }

  void _onClear() {
    setState(() {
      _pin = '';
      _errorMessage = '';
    });
  }

  Future<void> _processPin() async {
    final hasPasscode = _vaultService.hasPasscode;

    if (!hasPasscode) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _firstPin) {
          _vaultService.setPasscode(_pin).then((_) {
            widget.onSuccess();
          });
        } else {
          setState(() {
            _pin = '';
            _firstPin = '';
            _isConfirming = false;
            _errorMessage = 'PIN mismatch. Try again.';
          });
        }
      }
    } else {
      final success = await _vaultService.verifyPasscode(_pin);
      if (success) {
        widget.onSuccess();
      } else {
        setState(() {
          _pin = '';
          _errorMessage = 'Incorrect passcode.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPasscode = _vaultService.hasPasscode;
    String title = '';
    if (!hasPasscode) {
      title = _isConfirming ? 'CONFIRM PASSCODE' : 'NEW PASSCODE';
    } else {
      title = 'ENTER VAULT PASSCODE';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTxt = Theme.of(context).primaryColor;
    final subTxt = isDark ? Colors.white38 : Colors.black45;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const MinimalAnimatedBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24.0),
                    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151E2E).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Image.asset(
                          'assets/logo.png',
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: TextStyle(
                            color: primaryTxt,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !hasPasscode
                              ? 'Define a 4-digit code to encrypt data'
                              : 'Files are AES-256 encrypted',
                          style: TextStyle(
                            color: subTxt,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Simple Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _pin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled ? primaryTxt : Colors.transparent,
                                border: Border.all(
                                  color: filled ? primaryTxt : (isDark ? Colors.white24 : Colors.black26),
                                  width: 1.5,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        // Flat Error message
                        SizedBox(
                          height: 20,
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Keypad
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKey('1'),
                                  _buildKey('2'),
                                  _buildKey('3'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKey('4'),
                                  _buildKey('5'),
                                  _buildKey('6'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKey('7'),
                                  _buildKey('8'),
                                  _buildKey('9'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _canCheckBiometrics
                                      ? _buildIconButton(Icons.fingerprint, _triggerBiometrics, color: primaryTxt)
                                      : _buildIconButton(Icons.clear, _onClear),
                                  _buildKey('0'),
                                  _buildIconButton(Icons.backspace_outlined, _onBackspace),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    final primaryTxt = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => _onKeyPress(value),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: primaryTxt,
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    final primaryTxt = Theme.of(context).primaryColor;
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color ?? primaryTxt.withValues(alpha: 0.5),
          size: 20,
        ),
      ),
    );
  }
}
