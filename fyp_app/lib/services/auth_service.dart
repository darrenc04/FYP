import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register with email and password (for sign-up)
  Future<User?> registerWithEmail(String email, String password, String phoneNumber) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        final String docId = user.email!.toLowerCase();
        final docRef = _firestore.collection('Users').doc(docId);
        
        await docRef.set({
          'uid': user.uid,
          'email': user.email,
          'phoneNumber': phoneNumber,
          'deviceToken': '',
          'biometric': '',
          'lastDeviceRemoved': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // save user info if it doesn't already exists
      final User? user = result.user;

      if (user != null) {
        final String docId = user.email!.toLowerCase();
        final docRef = _firestore.collection('Users').doc(docId);
        final docSnap = await docRef.get();

        if (!docSnap.exists) {
          await docRef.set({
            'uid': user.uid,
            'email': user.email,
            'deviceToken': '',
            'biometric': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        final String docId = user.email!.toLowerCase();
        final docRef = _firestore.collection('Users').doc(docId);
        final docSnap = await docRef.get();

        if (!docSnap.exists) {
          await docRef.set({
            'uid': user.uid,
            'email': user.email,
            'deviceToken': '',
            'biometric': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return result.user;
    } catch (e) {
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
