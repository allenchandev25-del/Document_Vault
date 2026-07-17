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

  final List<String> _categories = [
    'All',
    'Images',
    'PDFs',
    'Documents',
    'Audio/Video',
    'Others'
  ];

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
        _processingMessage = 'Encrypting and securing files...';
      });

      for (final platformFile in result.files) {
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          await _vaultService.encryptAndAddFile(file);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully secured ${result.files.length} file(s)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: $e'),
          backgroundColor: Colors.redAccent,
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
      _processingMessage = 'Decrypting file...';
    });

    try {
      final tempPath = await _vaultService.decryptToTemp(item);
      setState(() {
        _isProcessing = false;
      });

      // If it's a common viewable type like Image, view inside the app!
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
        // Open with default system viewer
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
          ),
        );
      }
    }
  }

  Future<void> _exportFile(VaultItem item) async {
    try {
      final String? targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Decrypted File To...',
        fileName: item.originalName,
      );

      if (targetPath == null) return;

      setState(() {
        _isProcessing = true;
        _processingMessage = 'Decrypting & exporting file...';
      });

      await _vaultService.decryptFile(item, targetPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully exported to $targetPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.redAccent,
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete File', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete "${item.originalName}" from the vault? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Deleting file...';
    });

    try {
      await _vaultService.deleteFile(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
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
        return Colors.emerald;
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

  @override
  Widget build(BuildContext context) {
    // Filtered items
    final filteredItems = _vaultService.items.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch =
          item.originalName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    // Stats calculations
    int totalBytes = 0;
    final Map<String, int> categorySizes = {};
    for (var item in _vaultService.items) {
      totalBytes += item.sizeBytes;
      categorySizes[item.category] =
          (categorySizes[item.category] ?? 0) + item.sizeBytes;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 28),
            const SizedBox(width: 10),
            const Text(
              'Document Vault',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, py: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, color: Colors.greenAccent, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'AES-256',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lock Vault',
            icon: const Icon(Icons.lock_outline, color: Colors.white70),
            onPressed: () {
              _vaultService.lock();
              widget.onLock();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Stats Dashboard Panel
              _buildStatsPanel(totalBytes, categorySizes),
              
              // Search and Filters
              _buildSearchAndFilters(),

              // Items Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Secured Files (${filteredItems.length})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_vaultService.items.isNotEmpty)
                      Text(
                        'Total: ${VaultService.formatBytes(totalBytes)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),

              // Files List or Empty State
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState()
                    : _buildFilesList(filteredItems),
              ),
            ],
          ),

          // Modal HUD while processing
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32.0, vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _processingMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
        onPressed: _importFile,
      ),
    );
  }

  Widget _buildStatsPanel(int totalBytes, Map<String, int> categorySizes) {
    if (_vaultService.items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vault Storage Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar representing breakdown
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: _categories
                    .where((cat) => cat != 'All' && (categorySizes[cat] ?? 0) > 0)
                    .map((cat) {
                  final size = categorySizes[cat] ?? 0;
                  final percentage = totalBytes > 0 ? size / totalBytes : 0.0;
                  return Expanded(
                    flex: (percentage * 100).round().clamp(1, 100),
                    child: Container(
                      color: _getColorForCategory(cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _categories
                .where((cat) => cat != 'All' && (categorySizes[cat] ?? 0) > 0)
                .map((cat) {
              final size = categorySizes[cat] ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getColorForCategory(cat),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$cat (${VaultService.formatBytes(size)})',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search text field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search files...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        // Categories list
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  backgroundColor: const Color(0xFF1E293B),
                  selectedColor: Colors.blueAccent,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : Colors.white10,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasItemsAtAll = _vaultService.items.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasItemsAtAll ? Icons.search_off_outlined : Icons.folder_open_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            hasItemsAtAll
                ? 'No matches found'
                : 'Your Vault is Empty',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasItemsAtAll
                ? 'Try modifying your search criteria'
                : 'Click "Add Document" to encrypt and store files safely.',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
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
        final formattedDate =
            DateFormat('MMM dd, yyyy • hh:mm a').format(item.addedDate);
        final sizeStr = VaultService.formatBytes(item.sizeBytes);

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.03)),
          ),
          child: ListTile(
            onTap: () => _openFile(item),
            leading: CircleAvatar(
              backgroundColor: _getColorForCategory(item.category).withOpacity(0.15),
              child: Icon(
                _getIconForCategory(item.category),
                color: _getColorForCategory(item.category),
              ),
            ),
            title: Text(
              item.originalName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '$sizeStr • $formattedDate',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.download_outlined, color: Colors.blueAccent),
                  tooltip: 'Export (Decrypt & Save)',
                  onPressed: () => _exportFile(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Permanently',
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
