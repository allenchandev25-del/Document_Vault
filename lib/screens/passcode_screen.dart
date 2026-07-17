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
  String _firstPin = ''; // Used for setup
  bool _isConfirming = false;
  String _errorMessage = '';

  void _onKeyPress(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _errorMessage = '';
    });

    if (_pin.length == 4) {
      // Small delay for satisfying user visual feedback
      Future.delayed(const Duration(milliseconds: 200), _processPin);
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

  void _processPin() {
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
            _errorMessage = 'PINs do not match. Start over.';
          });
        }
      }
    } else {
      final success = _vaultService.verifyPasscode(_pin);
      if (success) {
        widget.onSuccess();
      } else {
        setState(() {
          _pin = '';
          _errorMessage = 'Incorrect passcode. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPasscode = _vaultService.hasPasscode;
    String title = '';
    if (!hasPasscode) {
      title = _isConfirming ? 'Confirm Passcode' : 'Create Passcode';
    } else {
      title = 'Enter Vault Passcode';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF1E1E38), // Soft dark purple
                Color(0xFF090D16), // Very dark blue/black
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 60,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 24),
              // Title text
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle/Instructions
              Text(
                !hasPasscode
                    ? 'Define a 4-digit PIN to secure your documents'
                    : 'Your files are AES encrypted and locked',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              // Dots indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Colors.blueAccent : Colors.transparent,
                      border: Border.all(
                        color: filled ? Colors.blueAccent : Colors.white30,
                        width: 2,
                      ),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              // Error Message
              SizedBox(
                height: 20,
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
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
                        _buildIconButton(Icons.clear, _onClear),
                        _buildKey('0'),
                        _buildIconButton(Icons.backspace_outlined, _onBackspace),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String value) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: () => _onKeyPress(value),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.01),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
