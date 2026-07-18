import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  
  // Navigation State
  int _currentTabIndex = 0;

  // Search Tab State
  final TextEditingController _searchTabQueryController = TextEditingController();
  String _searchTabQuery = '';
  String _searchTabCategory = 'All';
  String _searchTabSecurity = 'all';

  // Vault Tab State
  final TextEditingController _vaultQueryController = TextEditingController();
  String _vaultQuery = '';
  String _selectedVaultCategory = 'All';
  bool _isGridView = true; // Curvy grid view as default matches mockup

  // Photo Gallery State
  String _selectedGalleryFilter = 'All Photos'; 
  final Set<String> _favoriteIds = {};

  // Settings / Bio State
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
    _searchTabQueryController.dispose();
    _vaultQueryController.dispose();
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

      debugPrint('IMPORT SUCCESS: Secured ${result.files.length} file(s).');
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
      final isFlutterSupportedImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
      final isText = ext == '.txt';

      if (isFlutterSupportedImage || isText) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FileViewerScreen(
                filePath: tempPath,
                itemName: item.originalName,
                isImage: !isText,
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
      String? targetPath;
      String message = '';

      if (Platform.isAndroid) {
        final String downloadPath = p.join('/storage/emulated/0/Download', item.originalName);
        try {
          if (mounted) {
            setState(() {
              _isProcessing = true;
              _processingMessage = 'Exporting...';
            });
          }
          await _vaultService.decryptFile(item, downloadPath);
          targetPath = downloadPath;
          message = 'Saved to device Downloads folder';
        } catch (e) {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final String fallbackPath = p.join(extDir.path, item.originalName);
            await _vaultService.decryptFile(item, fallbackPath);
            targetPath = fallbackPath;
            message = 'Saved to app external files folder';
          } else {
            rethrow;
          }
        }
      } else {
        targetPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Export File To...',
          fileName: item.originalName,
        );
        if (targetPath != null) {
          if (mounted) {
            setState(() {
              _isProcessing = true;
              _processingMessage = 'Exporting...';
            });
          }
          await _vaultService.decryptFile(item, targetPath);
          message = 'File exported successfully';
        }
      }

      if (targetPath == null) {
        _vaultService.isPickingFile = false;
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            action: SnackBarAction(
              label: 'VIEW PATH',
              textColor: Colors.blueAccent,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Export Path', style: TextStyle(fontSize: 14)),
                    content: SelectableText(targetPath!, style: const TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF151E2E) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        title: const Text('Delete File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete "${item.originalName}"?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
      _favoriteIds.remove(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            backgroundColor: Colors.grey,
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

  Future<String?> _promptForCurrentPin() async {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.all(Radius.circular(24)),
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
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final isCorrect = await _vaultService.verifyPasscode(pin);
              if (isCorrect) {
                navigator.pop(pin);
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
                );
                navigator.pop();
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF151E2E) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        title: const Text('Change Security PIN', style: TextStyle(fontSize: 14, letterSpacing: 1.0)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Current PIN',
                counterText: '',
              ),
              onChanged: (val) => currentPin = val,
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'New 4-digit PIN',
                counterText: '',
              ),
              onChanged: (val) => newPin = val,
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Confirm New PIN',
                counterText: '',
              ),
              onChanged: (val) => confirmPin = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
            child: const Text('SAVE', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTxt = Theme.of(context).primaryColor;
    final subTxt = isDark ? const Color(0xFF969CB0) : const Color(0xFF5C6276);

    int totalBytes = 0;
    for (var item in _vaultService.items) {
      totalBytes += item.sizeBytes;
    }

    Widget currentBody;
    String appBarTitle = 'VAULT';
    List<Widget> appBarActions = [];

    switch (_currentTabIndex) {
      case 0:
        appBarTitle = 'MAIN VAULT';
        currentBody = _buildMainVaultTab(totalBytes, subTxt, primaryTxt, isDark);
        appBarActions = [
          IconButton(
            tooltip: 'View Mode',
            icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined, color: primaryTxt, size: 20),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            tooltip: 'Lock',
            icon: Icon(Icons.lock_outline, color: primaryTxt, size: 20),
            onPressed: () {
              _vaultService.lock();
              widget.onLock();
            },
          ),
          const SizedBox(width: 8),
        ];
        break;
      case 1:
        appBarTitle = 'PHOTO GALLERY';
        currentBody = _buildPhotosTab(isDark, primaryTxt, subTxt);
        break;
      case 2:
        appBarTitle = 'ADVANCED SEARCH';
        currentBody = _buildSearchTab(isDark, primaryTxt, subTxt);
        break;
      case 3:
        appBarTitle = 'UPLOAD CENTER';
        currentBody = _buildUploadsTab(isDark, primaryTxt, subTxt, totalBytes);
        break;
      case 4:
        appBarTitle = 'SECURITY SETTINGS';
        currentBody = _buildSettingsTab(isDark, primaryTxt, subTxt);
        break;
      default:
        currentBody = Container();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          appBarTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 15,
            color: primaryTxt,
          ),
        ),
        actions: appBarActions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Theme.of(context).dividerColor, height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          const MinimalAnimatedBackground(),
          currentBody,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: primaryTxt,
        unselectedItemColor: subTxt,
        selectedFontSize: 9,
        unselectedFontSize: 9,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'VAULT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.image_outlined),
            activeIcon: Icon(Icons.image),
            label: 'PHOTOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'SEARCH',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload_outlined),
            activeIcon: Icon(Icons.cloud_upload),
            label: 'UPLOADS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'SECURITY',
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              backgroundColor: primaryTxt,
              foregroundColor: Theme.of(context).scaffoldBackgroundColor,
              mini: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onPressed: _importFile,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // --- TAB BUILDERS ---

  // TAB 0: VAULT
  Widget _buildMainVaultTab(int totalBytes, Color subTxt, Color primaryTxt, bool isDark) {
    final filteredItems = _vaultService.items.where((item) {
      final matchesCategory = _selectedVaultCategory == 'All' || item.category == _selectedVaultCategory;
      final matchesSearch = item.originalName.toLowerCase().contains(_vaultQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_vaultService.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'STORAGE USED: ${VaultService.formatBytes(totalBytes)}',
                  style: TextStyle(
                    color: subTxt,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${_vaultService.items.length} TOTAL FILES',
                  style: TextStyle(
                    color: subTxt,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        
        // Search Filter (Glassmorphic Bar)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _vaultQueryController,
              onChanged: (val) {
                setState(() {
                  _vaultQuery = val;
                });
              },
              style: TextStyle(fontSize: 13, color: primaryTxt),
              decoration: InputDecoration(
                hintText: 'Search secure files...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, size: 16, color: subTxt),
                suffixIcon: _vaultQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 14, color: subTxt),
                        onPressed: () {
                          _vaultQueryController.clear();
                          setState(() {
                            _vaultQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),

        // Categories selector chips (translucent capsules)
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedVaultCategory == cat;
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
                      _selectedVaultCategory = cat;
                    });
                  },
                  selectedColor: primaryTxt,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  checkmarkColor: isDark ? Colors.black : Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.black : Colors.white) : subTxt,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12),
                      width: 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Files Area
        Expanded(
          child: filteredItems.isEmpty
              ? _buildEmptyState('NO FILES FOUND', 'Try adding files or clearing filters')
              : (_isGridView
                  ? _buildFilesGrid(filteredItems)
                  : _buildFilesList(filteredItems)),
        ),
      ],
    );
  }

  // TAB 1: PHOTOS
  Widget _buildPhotosTab(bool isDark, Color primaryTxt, Color subTxt) {
    final photoItems = _vaultService.items.where((item) {
      final ext = item.fileExtension.toLowerCase();
      final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
      final isFavoriteMatch = _selectedGalleryFilter == 'All Photos' || _favoriteIds.contains(item.id);
      return isImage && isFavoriteMatch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['All Photos', 'Favorites'].map((filter) {
              final isSelected = _selectedGalleryFilter == filter;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: ChoiceChip(
                  label: Text(
                    filter.toUpperCase(),
                    style: const TextStyle(fontSize: 10, letterSpacing: 1.0),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedGalleryFilter = filter;
                      });
                    }
                  },
                  selectedColor: primaryTxt,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  checkmarkColor: isDark ? Colors.black : Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.black : Colors.white) : subTxt,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: photoItems.isEmpty
              ? _buildEmptyState(
                  _selectedGalleryFilter == 'Favorites' ? 'NO FAVORITES' : 'NO PHOTOS',
                  _selectedGalleryFilter == 'Favorites' ? 'Star photos to add them here' : 'Import images to view them in the gallery')
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: photoItems.length,
                  itemBuilder: (context, index) {
                    final item = photoItems[index];
                    final isFav = _favoriteIds.contains(item.id);

                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _openFile(item),
                          child: GlassContainer(
                            borderRadius: 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VaultImagePreview(item: item),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color: Colors.black45,
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                      child: Text(
                                        item.originalName,
                                        style: const TextStyle(fontSize: 8, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isFav) {
                                  _favoriteIds.remove(item.id);
                                } else {
                                  _favoriteIds.add(item.id);
                                }
                              });
                            },
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black45,
                              child: Icon(
                                isFav ? Icons.star : Icons.star_border,
                                size: 14,
                                color: isFav ? Colors.amber : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 2: SEARCH
  Widget _buildSearchTab(bool isDark, Color primaryTxt, Color subTxt) {
    final searchResults = _vaultService.items.where((f) {
      final nameMatch = _searchTabQuery.isEmpty || f.originalName.toLowerCase().contains(_searchTabQuery.toLowerCase());
      final typeMatch = _searchTabCategory == 'All' || f.category == _searchTabCategory;
      final securityMatch = _searchTabSecurity == 'all' || (_searchTabSecurity == 'encrypted');
      return nameMatch && typeMatch && securityMatch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchTabQueryController,
                  onChanged: (val) {
                    setState(() {
                      _searchTabQuery = val;
                    });
                  },
                  style: TextStyle(fontSize: 13, color: primaryTxt),
                  decoration: InputDecoration(
                    hintText: 'Enter search text...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, size: 16, color: subTxt),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'FILTER BY CATEGORY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: subTxt),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _searchTabCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          cat.toUpperCase(),
                          style: const TextStyle(fontSize: 9),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _searchTabCategory = cat;
                            });
                          }
                        },
                        selectedColor: primaryTxt,
                        backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                        checkmarkColor: isDark ? Colors.black : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? (isDark ? Colors.black : Colors.white) : subTxt,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SECURITY STATE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: subTxt),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['all', 'encrypted'].map((sec) {
                  final isSelected = _searchTabSecurity == sec;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        sec.toUpperCase(),
                        style: const TextStyle(fontSize: 9),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _searchTabSecurity = sec;
                          });
                        }
                      },
                      selectedColor: primaryTxt,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      checkmarkColor: isDark ? Colors.black : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? (isDark ? Colors.black : Colors.white) : subTxt,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: searchResults.isEmpty
              ? _buildEmptyState('NO RESULTS', 'Try adjusting your search criteria')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final item = searchResults[index];
                    final dateStr = DateFormat('yyyy-MM-dd').format(item.addedDate);
                    final sizeStr = VaultService.formatBytes(item.sizeBytes);

                    return GlassContainer(
                      borderRadius: 16,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Icon(_getIconForCategory(item.category), color: primaryTxt),
                        ),
                        title: Text(item.originalName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('$sizeStr  |  $dateStr', style: TextStyle(fontSize: 10, color: subTxt)),
                        onTap: () => _openFile(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_outlined, size: 18),
                          onPressed: () => _exportFile(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 3: UPLOADS (UPLOAD CENTER)
  Widget _buildUploadsTab(bool isDark, Color primaryTxt, Color subTxt, int totalBytes) {
    const double limitBytes = 100 * 1024 * 1024; 
    final percent = (totalBytes / limitBytes).clamp(0.0, 1.0);
    final percentStr = (percent * 100).toStringAsFixed(1);
    final historyList = List<VaultItem>.from(_vaultService.items)
      ..sort((a, b) => b.addedDate.compareTo(a.addedDate));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage Status Card (Glass Container)
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 5,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryTxt),
                      ),
                    ),
                    Text(
                      '$percentStr%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryTxt),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STORAGE USAGE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTxt, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${VaultService.formatBytes(totalBytes)} of 100 MB Used',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTxt),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Offline safe storage limit',
                        style: TextStyle(fontSize: 10, color: subTxt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importFile,
                  icon: const Icon(Icons.add_to_photos_outlined, size: 18),
                  label: const Text('SECURE FILE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTxt,
                    foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Text(
            'UPLOAD HISTORY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTxt, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: historyList.isEmpty
                ? Center(
                    child: Text(
                      'NO UPLOADS YET',
                      style: TextStyle(fontSize: 11, color: subTxt, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.builder(
                    itemCount: historyList.length,
                    itemBuilder: (context, index) {
                      final item = historyList[index];
                      final sizeStr = VaultService.formatBytes(item.sizeBytes);
                      final timeStr = DateFormat('MM/dd HH:mm').format(item.addedDate);

                      return GlassContainer(
                        borderRadius: 16,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.cloud_done_outlined, color: Colors.green, size: 16),
                          title: Text(item.originalName, style: TextStyle(fontSize: 12, color: primaryTxt, fontWeight: FontWeight.bold)),
                          subtitle: Text('$sizeStr  |  $timeStr', style: TextStyle(fontSize: 9, color: subTxt)),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            onPressed: () => _openFile(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 4: SECURITY SETTINGS
  Widget _buildSettingsTab(bool isDark, Color primaryTxt, Color subTxt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THEME MODE',
              style: TextStyle(color: subTxt, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
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
                  selectedColor: primaryTxt,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  checkmarkColor: isDark ? Colors.black : Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.black : Colors.white) : subTxt,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        MainApp.themeNotifier.value = mode;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).dividerColor),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Fingerprint Unlock', style: TextStyle(color: primaryTxt, fontSize: 14)),
              subtitle: Text(
                _biometricSupported ? 'Unlock your vault using biometrics' : 'Biometrics not supported on this device',
                style: TextStyle(color: subTxt, fontSize: 11),
              ),
              trailing: _biometricSupported
                  ? Switch(
                      value: _vaultService.isBiometricEnabled,
                      activeThumbColor: primaryTxt,
                      onChanged: (val) async {
                        final pin = await _promptForCurrentPin();
                        if (pin != null) {
                          await _vaultService.setBiometricEnabled(val, pin);
                          setState(() {});
                        }
                      },
                    )
                  : null,
            ),
            Divider(color: Theme.of(context).dividerColor),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Change Security PIN', style: TextStyle(color: primaryTxt, fontSize: 14)),
              subtitle: Text('Modify your 4-digit vault passcode', style: TextStyle(color: subTxt, fontSize: 11)),
              trailing: Icon(Icons.arrow_forward_ios, color: subTxt, size: 14),
              onTap: _showChangePinDialog,
            ),
            Divider(color: Theme.of(context).dividerColor),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reset & Wipe Vault', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              subtitle: Text('Erase all encrypted documents and reset PIN', style: TextStyle(color: subTxt, fontSize: 11)),
              trailing: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF151E2E) : Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    title: Text('Reset Vault', style: TextStyle(color: primaryTxt, fontSize: 16, fontWeight: FontWeight.bold)),
                    content: const Text(
                      'Are you absolutely sure? This will permanently delete all secure documents and reset your login passcode. This cannot be undone.',
                      style: TextStyle(fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('CANCEL', style: TextStyle(color: subTxt, fontSize: 12)),
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
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _vaultService.lock();
                  widget.onLock();
                },
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('LOCK VAULT NOW'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUB-WIDGET BUILDERS ---

  Widget _buildEmptyState(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white30 : Colors.black38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
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
    final txtColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFF969CB0) : const Color(0xFF5C6276);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemsList.length,
      itemBuilder: (context, index) {
        final item = itemsList[index];
        final formattedDate = DateFormat('yyyy-MM-dd').format(item.addedDate);
        final sizeStr = VaultService.formatBytes(item.sizeBytes);

        return GlassContainer(
          borderRadius: 16,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            onTap: () => _openFile(item),
            leading: item.category == 'Images'
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: VaultImagePreview(item: item),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForCategory(item.category),
                      color: _getColorForCategory(item.category),
                      size: 20,
                    ),
                  ),
            title: Text(
              item.originalName,
              style: TextStyle(
                color: txtColor,
                fontWeight: FontWeight.bold,
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
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7), size: 18),
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
    final titleColor = Theme.of(context).primaryColor;
    final subColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF969CB0) : const Color(0xFF5C6276);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.88,
      ),
      itemCount: itemsList.length,
      itemBuilder: (context, index) {
        final item = itemsList[index];
        final sizeStr = VaultService.formatBytes(item.sizeBytes);

        return GestureDetector(
          onTap: () => _openFile(item),
          child: GlassContainer(
            borderRadius: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                item.category == 'Images'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 80,
                          height: 60,
                          child: VaultImagePreview(item: item),
                        ),
                      )
                    : Icon(
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
                      fontWeight: FontWeight.bold,
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
                const Divider(height: 1),
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.download_outlined, color: subColor, size: 16),
                          onPressed: () => _exportFile(item),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7), size: 16),
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

// PREMIUM GLASS CONTAINER WIDGET (Frosted Blur, Glass Borders, Drop Shadow)
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08) 
                    : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class VaultImagePreview extends StatefulWidget {
  final VaultItem item;
  final double width;
  final double height;
  final BoxFit fit;

  const VaultImagePreview({
    super.key,
    required this.item,
    this.width = double.infinity,
    this.height = double.infinity,
    this.fit = BoxFit.cover,
  });

  @override
  State<VaultImagePreview> createState() => _VaultImagePreviewState();
}

class _VaultImagePreviewState extends State<VaultImagePreview> {
  final VaultService _vaultService = VaultService();
  Uint8List? _decryptedBytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final decrypted = await _vaultService.decryptToBytes(widget.item);
      if (mounted) {
        setState(() {
          _decryptedBytes = decrypted;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(child: Icon(Icons.broken_image, size: 20, color: Colors.redAccent));
    }
    if (_decryptedBytes == null) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    return Image.memory(
      _decryptedBytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
