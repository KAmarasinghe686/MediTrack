import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // Initialize the text recognizer (defaults to Latin script)
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      StringBuffer extractedText = StringBuffer();
      
      // Read the scanned text block by block, preserving some layout
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText.writeln(line.text);
        }
        extractedText.writeln(); // Add extra spacing between blocks
      }
      
      return extractedText.toString().trim();
    } catch (e) {
      throw Exception("Failed to recognize text: $e");
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}