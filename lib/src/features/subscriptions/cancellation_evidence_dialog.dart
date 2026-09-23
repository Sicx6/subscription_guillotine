import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CancellationEvidenceDraft {
  const CancellationEvidenceDraft({
    required this.imagePath,
    required this.reference,
    required this.note,
  });

  final String imagePath;
  final String reference;
  final String note;
}

class CancellationEvidenceDialog extends StatefulWidget {
  const CancellationEvidenceDialog({super.key});

  @override
  State<CancellationEvidenceDialog> createState() =>
      _CancellationEvidenceDialogState();
}

class _CancellationEvidenceDialogState
    extends State<CancellationEvidenceDialog> {
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String? _imagePath;

  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image != null && mounted) setState(() => _imagePath = image.path);
  }

  Future<void> _chooseSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _pick(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pick(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  void _save() {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a screenshot or confirmation image.')),
      );
      return;
    }
    Navigator.pop(
      context,
      CancellationEvidenceDraft(
        imagePath: _imagePath!,
        reference: _reference.text,
        note: _note.text,
      ),
    );
  }

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add cancellation evidence'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imagePath!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _chooseSource,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_imagePath == null
                      ? 'Add confirmation image'
                      : 'Replace image'),
                ),
                TextField(
                  controller: _reference,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation reference (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _save, child: const Text('Save evidence')),
        ],
      );
}
