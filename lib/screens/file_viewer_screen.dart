import 'dart:io';
import 'package:flutter/material.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';

class FileViewerScreen extends StatefulWidget {
  final String filePath;
  final VaultItem item;
  final bool isImage;

  const FileViewerScreen({
    super.key,
    required this.filePath,
    required this.item,
    required this.isImage,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _isEditing = false;
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isImage) {
      _loadText();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadText() async {
    try {
      final content = await File(widget.filePath).readAsString();
      _textController.text = content;
    } catch (e) {
      debugPrint('Error loading text: $e');
    }
  }

  Future<void> _saveText() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await File(widget.filePath).writeAsString(_textController.text);
      await VaultService().updateTextFileContent(widget.item, _textController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          widget.item.originalName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!widget.isImage) ...[
            if (_isEditing)
              IconButton(
                tooltip: 'Save',
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                onPressed: _isLoading ? null : _saveText,
              )
            else
              IconButton(
                tooltip: 'Edit Note',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
          ]
        ],
      ),
      body: Center(
        child: widget.isImage
            ? InteractiveViewer(
                maxScale: 5.0,
                child: Image.file(
                  File(widget.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text(
                          'Error loading image file',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  },
                ),
              )
            : _isEditing
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type your secure note here...',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                      ),
                    ),
                  )
                : FutureBuilder<String>(
                    future: File(widget.filePath).readAsString(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error reading text: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SelectableText(
                            snapshot.data ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
