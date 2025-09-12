// frontend/lib/services/detection_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class DetectionService {
  final String _baseUrl = "http://127.0.0.1:5001";

  // This is the main method the app will call
  Future<http.Response> analyzeImage(XFile imageFile) async {
    // Check if the app is running on the web
    if (kIsWeb) {
      return _analyzeImageWeb(imageFile);
    } else {
      return _analyzeImageMobile(imageFile);
    }
  }

  // Method for Mobile (Android/iOS)
  Future<http.Response> _analyzeImageMobile(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze'));
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ),
    );
    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  // Method for Web
  Future<http.Response> _analyzeImageWeb(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze'));

    // Read the file as bytes
    final fileBytes = await imageFile.readAsBytes();

    // Create a MultipartFile from the bytes
    request.files.add(
      http.MultipartFile.fromBytes(
        'image', // The field name
        fileBytes,
        filename: imageFile.name, // Pass the original filename
      ),
    );
    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
}