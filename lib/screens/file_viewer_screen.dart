import 'dart:io';
import 'package:flutter/material.dart';

class FileViewerScreen extends StatelessWidget {
  final String filePath;
  final String itemName;
  final bool isImage;

  const FileViewerScreen({
    super.key,
    required this.filePath,
    required this.itemName,
    required this.isImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          itemName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: isImage
            ? InteractiveViewer(
                maxScale: 5.0,
                child: Image.file(
                  File(filePath),
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
            : FutureBuilder<String>(
                future: File(filePath).readAsString(),
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
                          color: Colors.white80,
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
