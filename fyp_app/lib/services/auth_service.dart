import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      print("DEBUG: Starting Google Sign-In");
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print("DEBUG: Google Sign-In aborted by user");
        return null;
      }

      print("DEBUG: Google User obtained: ${googleUser.email}");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("DEBUG: Signing in with credential");
      UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        print(
          "DEBUG: Firebase Auth successful. User: ${user.uid}, Email: ${user.email}",
        );
        if (user.email != null) {
          final String docId = user.email!.toLowerCase();
          final docRef = _firestore.collection('Users').doc(docId);

          try {
            final docSnap = await docRef.get();
            if (!docSnap.exists) {
              print("DEBUG: User not found in Firestore. Access denied.");
              await signOut();
              throw Exception(
                'Access denied. You are not registered in the system.',
              );
            }

            final data = docSnap.data() as Map<String, dynamic>;
            final role = data['role'] as String?;

            if (role != 'student' && role != 'teacher') {
              print("DEBUG: Invalid role: $role");
              await signOut();
              throw Exception(
                'Access denied. Only students and teachers can sign in.',
              );
            }

            print("DEBUG: User profile exists and has valid role: $role");

            if (data['uid'] != user.uid) {
              print("DEBUG: Updating Firestore UID to match Auth UID");
              await docRef.update({'uid': user.uid});
            }
          } catch (e) {
            print("DEBUG: Error accessing Firestore or validating user: $e");
            if (e.toString().contains('Access denied')) {
              rethrow;
            }
            await signOut();
            throw Exception(
              'Login failed: Unable to verify user profile. Please try again.',
            );
          }
        } else {
          print("DEBUG: User email is null. Cannot check Firestore profile.");
          await signOut();
          throw Exception('Login failed: Email is required.');
        }
      } else {
        print("DEBUG: Firebase Auth returned null user");
      }

      return result.user;
    } catch (e) {
      print("DEBUG: Error in signInWithGoogle: $e");
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Update User Profile in Firestore
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      // We assume the document ID is the user's email, but we might not have it easily here if we only pass UID.
      // However, in the register/login logic, docId = user.email!.toLowerCase().
      // So we need to find the document.
      // A safer way if we don't have email is to query by uid field, but the docID is email.
      // Let's try to get the current user's email from Auth if possible, or pass it.
      // Actually, the best way is to query where 'uid' == uid if we are not sure about email,
      // OR just use the current logged in user's email.

      final user = _auth.currentUser;
      if (user != null) {
        final String docId = user.email!.toLowerCase();
        await _firestore.collection('Users').doc(docId).update(data);
      } else {
        throw Exception('No user logged in');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Upload Profile Picture
  Future<String> uploadProfilePicture(File image) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final userEmail = user.email!.toLowerCase();
      final fileName =
          'profile_picture_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Firebase Storage: users/{email}/profile_picture
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/$userEmail')
          .child(fileName);

      await storageRef.putFile(image);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore with the image URL
      await _firestore.collection('Users').doc(userEmail).update({
        'profilePicture': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Change Password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Check if email exists in Users collection
      final docId = email.toLowerCase();
      final docSnap = await _firestore.collection('Users').doc(docId).get();

      if (!docSnap.exists) {
        throw Exception('Email not found in our records');
      }

      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Future<User?> signInWithApple() async {
  //   try {
  //     final appleCredential = await SignInWithApple.getAppleIDCredential(
  //       scopes: [
  //         AppleIDAuthorizationScopes.email,
  //         AppleIDAuthorizationScopes.fullName,
  //       ],
  //     );

  //     final oauthCredential = OAuthProvider("apple.com").credential(
  //       idToken: appleCredential.identityToken,
  //       accessToken: appleCredential.authorizationCode,
  //     );

  //     UserCredential result =
  //         await _auth.signInWithCredential(oauthCredential);
  //     return result.user;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }
}
