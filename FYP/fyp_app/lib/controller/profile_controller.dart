import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../model/profile_user_data.dart';

/// Controller to handle profile page business logic
class ProfileController {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  /// Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Fetch user data from Firestore
  Future<ProfileUserData?> fetchUserData() async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return null;

      final email = currentUser.email;
      if (email == null) return null;

      final doc = await _firestore.collection('Users').doc(email).get();
      if (!doc.exists) return null;

      return ProfileUserData.fromFirestore(doc.data()!, email);
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  /// Update a specific user profile field
  Future<bool> updateUserField(String field, String value) async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) return false;

      await _authService.updateUserProfile(currentUser.uid, {field: value});
      return true;
    } catch (e) {
      print('Error updating field $field: $e');
      return false;
    }
  }

  /// Pick image from gallery and upload to Firebase Storage
  Future<bool> pickAndUploadImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return false;

      final file = File(pickedFile.path);
      await _authService.uploadProfilePicture(file);
      return true;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return false;
    }
  }

  /// Change user password
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _authService.changePassword(oldPassword, newPassword);
  }
}
