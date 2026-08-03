import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/record_service.dart';

class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  OcrScannerScreenState createState() => OcrScannerScreenState();
}

class OcrScannerScreenState extends State<OcrScannerScreen> {
  final OcrService _ocrService = OcrService();
  final RecordService _recordService = RecordService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  File? _imageFile;
  bool _isProcessing = false;
  bool _isSaving = false;

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _isProcessing = true;
        _textController.clear();
      });

      // Run ML Kit Text Recognition
      final extractedText = await _ocrService.extractTextFromImage(_imageFile!);
      
      setState(() {
        _textController.text = extractedText;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning report: $e')),
      );
    }
  }

  Future<void> _saveDigitalRecord() async {
    if (_imageFile == null || _textController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _recordService.uploadNewRecord(
        file: _imageFile!,
        title: 'Scanned medical report - ${DateTime.now().toLocal().toString().substring(0, 10)}',
        type: 'Scan',
        extractedText: _textController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digital record saved successfully.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save record: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Medical Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Image Preview Area
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(
                        'No image selected',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
            ),
            SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Camera'),
                  onPressed: () => _pickAndProcessImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                  onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Results Area
            Expanded(
              child: _isProcessing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Analyzing text via ML Kit...'),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _textController,
                      onChanged: (_) => setState(() {}),
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        labelText: 'Extracted Text (Editable)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
            ),
            SizedBox(height: 16),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _textController.text.trim().isEmpty || _isSaving
                    ? null
                    : _saveDigitalRecord,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save as Digital Record',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
