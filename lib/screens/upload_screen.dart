import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/record_service.dart';
import 'ocr_scanner_screen.dart';
import '../widgets/screen_heroes.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final RecordService _recordService = RecordService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedFile;
  String? _fileName;
  String? _fileExtension;
  final TextEditingController _titleController = TextEditingController();
  String _selectedType = 'Lab Result';
  bool _isUploading = false;

  final List<String> _recordTypes = [
    'Lab Result',
    'Prescription',
    'Scan',
    'Medical Report',
    'Other',
  ];

  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      
      if (file != null) {
        _setFile(File(file.path), file.name);
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  // Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      
      if (file != null) {
        _setFile(File(file.path), file.name);
      }
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  // ✅ Pick PDF - SIMPLE AND WORKING
  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        _setFile(file, result.files.single.name);
      }
    } catch (e) {
      _showError('Error picking PDF: $e');
    }
  }

  Future<void> _scanMedicalReport() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OcrScannerScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanned record saved to your records.')),
      );
    }
  }

  void _setFile(File file, String name) {
    setState(() {
      _selectedFile = file;
      _fileName = name;
      _fileExtension = name.split('.').last.toLowerCase();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Selected: $name'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a file to upload',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.blue,
                    onTap: () { Navigator.pop(context); _pickImageFromGallery(); },
                  ),
                  _buildOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.green,
                    onTap: () { Navigator.pop(context); _pickImageFromCamera(); },
                  ),
                  _buildOption(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    color: Colors.red,
                    onTap: () { Navigator.pop(context); _pickPDF(); },
                  ),
                  _buildOption(
                    icon: Icons.document_scanner_rounded,
                    label: 'Scan',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      _scanMedicalReport();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadRecord() async {
    if (_selectedFile == null) {
      _showError('Please select a file first');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a title');
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _recordService.uploadNewRecord(
        file: _selectedFile!,
        title: _titleController.text.trim(),
        type: _selectedType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        setState(() {
          _selectedFile = null;
          _fileName = null;
          _fileExtension = null;
          _titleController.clear();
        });
        
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Medical Record'),
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                _selectedFile = null;
                _fileName = null;
                _fileExtension = null;
              }),
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediTrackImageBanner(
                imageUrl: 'assets/images/upload_records_pastel_cartoon.png',
                title: 'Add a health record',
                subtitle: 'Keep reports and prescriptions ready when care needs them.',
                icon: Icons.upload_file_rounded,
                showOverlay: false,
                fullWhiteOverlayOpacity: 0.56,
              ),
              const SizedBox(height: 20),
              // File selection area
            InkWell(
              onTap: _isUploading ? null : _showSourceSheet,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedFile != null ? Colors.green : Colors.grey.shade300,
                    width: _selectedFile != null ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: _selectedFile != null
                    ? _fileExtension == 'pdf'
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf, size: 64, color: Colors.red.shade700),
                                const SizedBox(height: 8),
                                Text(
                                  _fileName ?? 'PDF selected',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PDF',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(_selectedFile!, fit: BoxFit.cover),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.6),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _fileName ?? 'Image selected',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SELECTED',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Tap to select file', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          Text('Image or PDF', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Supports JPG, PNG, PDF',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              enabled: !_isUploading,
              decoration: const InputDecoration(
                labelText: 'Document Title *',
                hintText: 'e.g., Blood Test Report - June 2024',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Document Type',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              items: _recordTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: _isUploading ? null : (value) {
                if (value != null) setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadRecord,
                icon: _isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isUploading ? 'Uploading...' : 'Upload Record',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            if (_isUploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Uploading to secure cloud storage...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your documents are securely stored in Firebase Storage and only accessible to you.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
