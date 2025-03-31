import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  // Register with email & password
  Future<User?> registerWithEmail(
      String username, String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Store user data in Firestore with UID as the document ID
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'email': email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } catch (e) {
      print("Error during registration: $e");
      return null;
    }
  }

  // Login with email & password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Fetch user role from Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

          if (data.containsKey('role') && data['role'] == 'admin') {
            print("Admin logged in.");
          } else {
            print("Regular user logged in.");
          }
        }
      }

      return user;
    } catch (e) {
      print("Error during sign in: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get the current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
