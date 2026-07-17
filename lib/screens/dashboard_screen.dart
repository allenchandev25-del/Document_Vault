import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';
import 'file_viewer_screen.dart';
import '../main.dart';
import '../widgets/animated_background.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLock;

  const DashboardScreen({super.key, required this.onLock});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final VaultService _vaultService = VaultService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isProcessing = false;
  String _processingMessage = '';
  bool _biometricSupported = false;
  bool _isGridView = false;

  final List<String> _categories = [
    'All',
    'Images',
    'PDFs',
    'Documents',
    'Audio/Video',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _checkBiometricHardware();
  }

  Future<void> _checkBiometricHardware() async {
    final supported = await _vaultService.canUseBiometrics();
    setState(() {
      _biometricSupported = supported;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFile() async {
    try {
      _vaultService.isPickingFile = true;
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _vaultService.isPickingFile = false;
        return;
      }

      if (mounted) {
        setState(() {
          _isProcessing = true;
          _processingMessage = 'Securing...';
        });
      }

      for (final platformFile in result.files) {
        if (platformFile.bytes != null) {
          await _vaultService.encryptAndAddBytes(platformFile.bytes!, platformFile.name);
        } else if (platformFile.path != null) {
          final file = File(platformFile.path!);
          await _vaultService.encryptAndAddFile(file);
        }
      }

      debugPrint('IMPORT SUCCESS: Secured ${result.files.length} file(s). Total vault items: ${_vaultService.items.length}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Secured ${result.files.length} file(s)'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('IMPORT ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _vaultService.isPickingFile = false;
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _openFile(VaultItem item) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Decrypting...';
    });

    try {
      final tempPath = await _vaultService.decryptToTemp(item);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      final ext = item.fileExtension.toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif', '.txt'].contains(ext)) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FileViewerScreen(
                filePath: tempPath,
                itemName: item.originalName,
                isImage: ext != '.txt',
              ),
            ),
          );
        }
      } else {
        await OpenFilex.open(tempPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportFile(VaultItem item) async {
    try {
      _vaultService.isPickingFile = true;
      final String? targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export File To...',
        fileName: item.originalName,
      );

      if (targetPath == null) {
        _vaultService.isPickingFile = false;
        return;
      }

      setState(() {
        _isProcessing = true;
        _processingMessage = 'Exporting...';
      });

      await _vaultService.decryptFile(item, targetPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to ${targetPath.split(Platform.pathSeparator).last}'),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _vaultService.isPickingFile = false;
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteFile(VaultItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        title: const Text('Delete File', style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 0.5)),
        content: Text(
          'Permanently delete "${item.originalName}"?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Deleting...';
    });

    try {
      await _vaultService.deleteFile(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            backgroundColor: Colors.white24,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: Border(
        top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final txtColor = isDark ? Colors.white : Colors.black;
            final subColor = isDark ? Colors.white38 : Colors.black45;

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SETTINGS',
                      style: TextStyle(
                        color: txtColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    // Theme Choice Chips
                    Text(
                      'THEME MODE',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ThemeMode.system,
                        ThemeMode.dark,
                        ThemeMode.light,
                      ].map((mode) {
                        final isSelected = MainApp.themeNotifier.value == mode;
                        String modeName = '';
                        if (mode == ThemeMode.system) modeName = 'SYSTEM';
                        if (mode == ThemeMode.dark) modeName = 'DARK';
                        if (mode == ThemeMode.light) modeName = 'LIGHT';

                        return ChoiceChip(
                          label: Text(
                            modeName,
                            style: const TextStyle(fontSize: 9, letterSpacing: 0.5),
                          ),
                          selected: isSelected,
                          selectedColor: isDark ? Colors.white : Colors.black,
                          backgroundColor: Colors.transparent,
                          checkmarkColor: isDark ? Colors.black : Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark ? Colors.white12 : Colors.black12),
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                MainApp.themeNotifier.value = mode;
                              });
                              setState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Theme.of(context).dividerColor),
                    // Fingerprint Toggle
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Fingerprint Unlock',
                        style: TextStyle(color: txtColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        _biometricSupported
                            ? 'Unlock your vault using biometrics'
                            : 'Biometrics not supported on this device',
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                      trailing: _biometricSupported
                          ? Switch(
                              value: _vaultService.isBiometricEnabled,
                              activeThumbColor: isDark ? Colors.white : Colors.black,
                              activeTrackColor: isDark ? Colors.white30 : Colors.black12,
                              onChanged: (val) async {
                                final pin = await _promptForCurrentPin();
                                if (pin != null) {
                                  await _vaultService.setBiometricEnabled(val, pin);
                                  setModalState(() {});
                                  setState(() {});
                                }
                              },
                            )
                          : null,
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    // Change Passcode
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Change Security PIN',
                        style: TextStyle(color: txtColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Modify your 4-digit vault passcode',
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, color: subColor, size: 14),
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePinDialog();
                      },
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    // Wipe Vault
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Reset & Wipe Vault',
                        style: TextStyle(color: Colors.redAccent, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Erase all encrypted documents and reset PIN',
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                      onTap: () async {
                        Navigator.pop(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                            ),
                            title: Text('Reset Vault', style: TextStyle(color: txtColor, fontSize: 16, letterSpacing: 0.5)),
                            content: const Text(
                              'Are you absolutely sure? This will permanently delete all secure documents and reset your login passcode. This cannot be undone.',
                              style: TextStyle(fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('CANCEL', style: TextStyle(color: subColor, fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('RESET VAULT', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          setState(() {
                            _isProcessing = true;
                            _processingMessage = 'Resetting...';
                          });
                          await _vaultService.wipeVault();
                          setState(() {
                            _isProcessing = false;
                          });
                          widget.onLock();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _promptForCurrentPin() async {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        title: const Text('Confirm PIN', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.0)),
        content: TextField(
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, letterSpacing: 4.0),
          decoration: const InputDecoration(
            hintText: 'Enter current PIN',
            hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
            counterText: '',
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
          onChanged: (val) => pin = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
          TextButton(
            onPressed: () async {
              if (await _vaultService.verifyPasscode(pin)) {
                Navigator.pop(context, pin);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    String currentPin = '';
    String newPin = '';
    String confirmPin = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        title: const Text('Change Security PIN', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Current PIN',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
              onChanged: (val) => currentPin = val,
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'New 4-digit PIN',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
              onChanged: (val) => newPin = val,
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Confirm New PIN',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
              onChanged: (val) => confirmPin = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
          TextButton(
            onPressed: () async {
              if (newPin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New PINs do not match'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              if (newPin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits'), backgroundColor: Colors.redAccent),
                );
                return;
              }

              final success = await _vaultService.changePasscode(currentPin, newPin);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN successfully changed'), backgroundColor: Colors.green),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Current PIN incorrect'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _vaultService.items.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch =
          item.originalName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    int totalBytes = 0;
    for (var item in _vaultService.items) {
      totalBytes += item.sizeBytes;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTxt = Theme.of(context).primaryColor;
    final subTxt = isDark ? Colors.white38 : Colors.black45;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'VAULT',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            letterSpacing: 2.0,
            fontSize: 15,
            color: primaryTxt,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, color: primaryTxt.withValues(alpha: 0.7), size: 20),
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            tooltip: 'Lock',
            icon: Icon(Icons.lock_outline, color: primaryTxt.withValues(alpha: 0.7), size: 20),
            onPressed: () {
              _vaultService.lock();
              widget.onLock();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Theme.of(context).dividerColor, height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          const MinimalAnimatedBackground(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Minimal Storage Summary Row
              if (_vaultService.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STORAGE: ${VaultService.formatBytes(totalBytes)}',
                        style: TextStyle(
                          color: subTxt,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '${_vaultService.items.length} FILES',
                        style: TextStyle(
                          color: subTxt,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Search Field & View Toggler Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black38,
                            fontSize: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45,
                            size: 16,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45,
                                    size: 14,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
                          size: 18,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Categories Row
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          cat.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            letterSpacing: 1.0,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        selectedColor: isDark ? Colors.white : Colors.black,
                        backgroundColor: Colors.transparent,
                        checkmarkColor: isDark ? Colors.black : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Files List or Grid
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState()
                    : (_isGridView
                        ? _buildFilesGrid(filteredItems)
                        : _buildFilesList(filteredItems)),
              ),
            ],
          ),

          // Processing Overlay HUD
          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _processingMessage.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
        mini: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onPressed: _importFile,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasItemsAtAll = _vaultService.items.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasItemsAtAll ? 'NO MATCHES' : 'EMPTY VAULT',
            style: TextStyle(
              color: isDark ? Colors.white30 : Colors.black38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasItemsAtAll ? 'Refine search terms' : 'Add documents to secure them',
            style: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<VaultItem> itemsList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final txtColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white38 : Colors.black45;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemsList.length,
      itemBuilder: (context, index) {
        final item = itemsList[index];
        final formattedDate = DateFormat('yyyy-MM-dd').format(item.addedDate);
        final sizeStr = VaultService.formatBytes(item.sizeBytes);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            onTap: () => _openFile(item),
            title: Text(
              item.originalName,
              style: TextStyle(
                color: txtColor,
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$sizeStr  |  $formattedDate  |  ${item.category.toUpperCase()}',
              style: TextStyle(
                color: subColor,
                fontSize: 10,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.download_outlined, color: subColor, size: 18),
                  tooltip: 'Export',
                  onPressed: () => _exportFile(item),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: subColor, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _deleteFile(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesGrid(List<VaultItem> itemsList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final cardColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9F9F9);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white38 : Colors.black45;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: itemsList.length,
      itemBuilder: (context, index) {
        final item = itemsList[index];
        final sizeStr = VaultService.formatBytes(item.sizeBytes);

        return GestureDetector(
          onTap: () => _openFile(item),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Icon(
                  _getIconForCategory(item.category),
                  color: _getColorForCategory(item.category),
                  size: 28,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    item.originalName,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sizeStr,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  height: 1,
                  color: borderColor,
                ),
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.download_outlined, color: subColor, size: 14),
                          onPressed: () => _exportFile(item),
                        ),
                      ),
                      Container(
                        width: 1,
                        color: borderColor,
                      ),
                      Expanded(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7), size: 14),
                          onPressed: () => _deleteFile(item),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Images':
        return Icons.image_outlined;
      case 'PDFs':
        return Icons.picture_as_pdf_outlined;
      case 'Documents':
        return Icons.description_outlined;
      case 'Audio/Video':
        return Icons.video_library_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Images':
        return const Color(0xFF10B981);
      case 'PDFs':
        return Colors.redAccent;
      case 'Documents':
        return Colors.blueAccent;
      case 'Audio/Video':
        return Colors.orangeAccent;
      default:
        return Colors.purpleAccent;
    }
  }
}
