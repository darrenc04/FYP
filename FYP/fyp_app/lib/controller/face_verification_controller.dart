import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../model/face_verification_result.dart';

class FaceVerificationController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  static const String DEEPFACE_API_URL = 'http://192.168.1.106:5000';

  /// Check if DeepFace server is available
  Future<bool> checkServerHealth() async {
    try {
      final healthResponse = await http
          .get(Uri.parse('$DEEPFACE_API_URL/health'))
          .timeout(const Duration(seconds: 5));

      return healthResponse.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  /// Capture video from front camera
  Future<XFile?> captureVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(seconds: 10),
      );
      return video;
    } catch (e) {
      debugPrint('Error capturing video: $e');
      return null;
    }
  }

  /// Verify face and detect eye blinks using DeepFace API
  Future<FaceVerificationResult> verifyFaceAndDetectBlinks(
    String userId,
    XFile video,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DEEPFACE_API_URL/verify-face-and-blinks'),
      );

      request.fields['user_id'] = userId;
      request.files.add(await http.MultipartFile.fromPath('video', video.path));

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final responseBody = await response.stream.bytesToString();

      debugPrint(
        'Face + Blink verification response status: ${response.statusCode}',
      );
      debugPrint('Face + Blink verification response body: $responseBody');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(responseBody);
        return FaceVerificationResult.fromJson({'success': true, ...jsonData});
      } else if (response.statusCode == 404) {
        return FaceVerificationResult(
          success: false,
          error: 'User face not registered. Please register first.',
        );
      } else {
        return FaceVerificationResult(
          success: false,
          error: 'Verification failed: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error in verifyFaceAndDetectBlinks: $e');
      return FaceVerificationResult(
        success: false,
        error: 'Verification error: $e',
      );
    }
  }

  /// Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Get user email in lowercase
  String? getUserEmail() {
    final user = getCurrentUser();
    return user?.email?.toLowerCase();
  }
}
