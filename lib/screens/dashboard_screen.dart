import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';
import 'file_viewer_screen.dart';

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
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _processingMessage = 'Securing...';
      });

      for (final platformFile in result.files) {
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          await _vaultService.encryptAndAddFile(file);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Secured ${result.files.length} file(s)'),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _openFile(VaultItem item) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Decrypting...';
    });

    try {
      final tempPath = await _vaultService.decryptToTemp(item);
      setState(() {
        _isProcessing = false;
      });

      final ext = item.fileExtension.toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.txt'].contains(ext)) {
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
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
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
      final String? targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export File To...',
        fileName: item.originalName,
      );

      if (targetPath == null) return;

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
      setState(() {
        _isProcessing = false;
      });
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
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF000000),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.white12, width: 1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SETTINGS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Fingerprint Toggle
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Fingerprint Unlock',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        _biometricSupported
                            ? 'Unlock your vault using biometrics'
                            : 'Biometrics not supported on this device',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      trailing: _biometricSupported
                          ? Switch(
                              value: _vaultService.isBiometricEnabled,
                              activeColor: Colors.white,
                              inactiveTrackColor: Colors.white10,
                              activeTrackColor: Colors.white30,
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
                    const Divider(color: Colors.white10),
                    // Change Passcode
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Change Security PIN',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Modify your 4-digit vault passcode',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePinDialog();
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
            onPressed: () {
              if (_vaultService.verifyPasscode(pin)) {
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
              if (mounted) {
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

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure Black Minimalist
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text(
          'VAULT',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            letterSpacing: 2.0,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            tooltip: 'Lock',
            icon: const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
            onPressed: () {
              _vaultService.lock();
              widget.onLock();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white10, height: 1.0),
        ),
      ),
      body: Stack(
        children: [
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
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '${_vaultService.items.length} FILES',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 16),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 14),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF0F0F0F),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
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
                        selectedColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white60,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : Colors.white12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Files List
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState()
                    : _buildFilesList(filteredItems),
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
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        mini: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onPressed: _importFile,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasItemsAtAll = _vaultService.items.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasItemsAtAll ? 'NO MATCHES' : 'EMPTY VAULT',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasItemsAtAll ? 'Refine search terms' : 'Add documents to secure them',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<VaultItem> itemsList) {
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
            border: Border.all(color: Colors.white12, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            onTap: () => _openFile(item),
            title: Text(
              item.originalName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$sizeStr  |  $formattedDate  |  ${item.category.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.download_outlined, color: Colors.white54, size: 18),
                  tooltip: 'Export',
                  onPressed: () => _exportFile(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
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
}
