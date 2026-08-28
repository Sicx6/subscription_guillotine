import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'confirmation_screen.dart';
import 'receipt_scanner_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = ReceiptScannerService();
  bool _scanning = false;
  String? _imagePath;

  Future<void> _scan(ImageSource source) async {
    setState(() => _scanning = true);
    try {
      final result = await _scanner.scan(source);
      if (!mounted || result == null) return;
      setState(() => _imagePath = result.imagePath);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmationScreen(result: result),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not scan this receipt: $error')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCAN RECEIPT'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_imagePath != null)
            Image.file(File(_imagePath!), fit: BoxFit.cover)
          else
            const _ReceiptPlaceholder(),
          Container(color: Colors.black.withOpacity(0.15)),
          Center(
            child: Container(
              width: 290,
              height: 390,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child:
                    Icon(Icons.receipt_long, color: Colors.white54, size: 96),
              ),
            ),
          ),
          if (_scanning)
            ColoredBox(
              color: Colors.black.withOpacity(0.55),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 18),
                    Text('Detecting text…',
                        style: TextStyle(color: Colors.white, fontSize: 17)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _scanning ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _scanning ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptPlaceholder extends StatelessWidget {
  const _ReceiptPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB59C7D), Color(0xFF68513D)],
          ),
        ),
      );
}
