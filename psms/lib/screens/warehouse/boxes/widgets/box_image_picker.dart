// box_image_picker.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BoxImagePickerWidget extends StatefulWidget {
  final File? initialImageFile;
  final ValueChanged<File?> onImageSelected;

  const BoxImagePickerWidget({
    super.key,
    this.initialImageFile,
    required this.onImageSelected,
  });

  @override
  State<BoxImagePickerWidget> createState() => _BoxImagePickerWidgetState();
}

class _BoxImagePickerWidgetState extends State<BoxImagePickerWidget> {
  final _picker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialImageFile;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => _imageFile = file);
    widget.onImageSelected(file);
  }

  void _clear() {
    setState(() => _imageFile = null);
    widget.onImageSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Box Image',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        if (_imageFile != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!,
                    height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _clear,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            _pickBtn('Gallery', Icons.photo_library, () => _pickImage(ImageSource.gallery)),
            const SizedBox(width: 8),
            if (!Platform.isWindows)
              _pickBtn('Camera', Icons.camera_alt, () => _pickImage(ImageSource.camera)),
          ],
        ),
      ],
    );
  }

  Widget _pickBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}