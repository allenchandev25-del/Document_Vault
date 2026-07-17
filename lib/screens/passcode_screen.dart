import 'package:flutter/material.dart';
import '../services/vault_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure Black Minimalist
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Minimal Header
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !hasPasscode
                  ? 'Define a 4-digit code to encrypt data'
                  : 'Files are AES-256 encrypted',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(flex: 1),
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
                    color: filled ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: filled ? Colors.white : Colors.white24,
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
            const Spacer(flex: 2),
            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
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
                          ? _buildIconButton(Icons.fingerprint, _triggerBiometrics, color: Colors.blueAccent)
                          : _buildIconButton(Icons.clear, _onClear),
                      _buildKey('0'),
                      _buildIconButton(Icons.backspace_outlined, _onBackspace),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String value) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => _onKeyPress(value),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
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
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color ?? Colors.white54,
          size: 20,
        ),
      ),
    );
  }
}
