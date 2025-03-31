import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  //======================STUDY MATERIAL============================================
  // Upload a file to Firebase Storage and return its URL
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      Reference ref = _storage.ref().child('study_materials/$fileName');
      UploadTask uploadTask = ref.putFile(File(filePath));

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print("✅ File uploaded: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("❌ Error uploading file: $e");
      return null;
    }
  }

  // Upload File to Firebase Storage & Post Study Material
  Future<void> postStudyMaterial(File file, String title) async {
    try {
      final user = _auth.currentUser!;
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload file to storage
      final ref = _storage.ref().child("study_materials/$fileName");
      final snapshot = await ref.putFile(file).whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save to Firestore with UPLOADER EMAIL
      await _db.collection('study_materials').add({
        'title': title,
        'url': downloadUrl,
        'uploader': user.email!,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      });
    } catch (e) {
      print("Error posting study material: $e");
    }
  }

  Stream<QuerySnapshot> getStudyMaterials() {
    return FirebaseFirestore.instance
        .collection('study_materials')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Like a Study Material (Prevents double-liking)
  Future<void> likeMaterial(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      DocumentSnapshot doc =
          await _db.collection('study_materials').doc(docId).get();
      List likedBy = doc['likedBy'];

      if (likedBy.contains(user.email)) return;

      await _db.collection('study_materials').doc(docId).update({
        'likedBy': FieldValue.arrayUnion([user.email]),
        'likes': FieldValue.increment(1),
      });
      print("✅ Study material liked successfully!");
    } catch (e) {
      print("❌ Error liking study material: $e");
    }
  }

  // Delete a Study Material (Only the uploader can delete)
  Future<void> deleteStudyMaterial(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      DocumentSnapshot doc =
          await _db.collection('study_materials').doc(docId).get();
      if (doc['uploader'] != user.email) return;

      await _db.collection('study_materials').doc(docId).delete();
    } catch (e) {
      print("Error deleting study material: $e");
    }
  }

//========================================HELP REQUEST=========================================================
  // Post a new Help Request

  Future<void> postHelpRequest(String title, String description) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      await _db.collection('help_requests').add({
        'title': title,
        'description': description,
        'uploader': user.email,
        'upvotes': 0,
        'flags': 0,
        'likedBy': [],
        'flaggedBy': [],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error posting help request: $e");
    }
  }

  // Upvote a request (add user email to likedBy)
  Future<void> likeRequest(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      await _db.collection('help_requests').doc(docId).update({
        'likedBy': FieldValue.arrayUnion([user.email]),
        'upvotes': FieldValue.increment(1),
      });
    } catch (e) {}
  }

  // Remove Like (remove user email from likedBy)
  Future<void> removeLike(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      await _db.collection('help_requests').doc(docId).update({
        'likedBy': FieldValue.arrayRemove([user.email]),
        'upvotes': FieldValue.increment(-1),
      });
    } catch (e) {}
  }

// Flagging system
  Future<void> flagRequest(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      await _db.collection('help_requests').doc(docId).update({
        'flaggedBy': FieldValue.arrayUnion([user.email]),
        'flags': FieldValue.increment(1),
      });
    } catch (e) {
      print("Error flagging request: $e");
    }
  }

  // Remove Flag (remove user email from flaggedBy)
  Future<void> removeFlag(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      await _db.collection('help_requests').doc(docId).update({
        'flaggedBy': FieldValue.arrayRemove([user.email]),
        'flags': FieldValue.increment(-1),
      });
    } catch (e) {
      print("Error removing flag: $e");
      rethrow;
    }
  }

  // Delete a Help Request
  Future<void> deleteHelpRequest(String docId) async {
    try {
      await _db.collection('help_requests').doc(docId).delete();
      print("✅ Help request deleted successfully!");
    } catch (e) {
      print("❌ Error deleting help request: $e");
    }
  }

  Future<void> updateHelpRequest(
      String docId, String title, String description) async {
    try {
      await _db.collection('help_requests').doc(docId).update({
        'title': title,
        'description': description,
      });
    } catch (e) {
      print("Error updating help request: $e");
      rethrow;
    }
  }

  // Get all help requests (Real-time updates)
  Stream<QuerySnapshot> getHelpRequests() {
    return _db
        .collection('help_requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ========================== FLAGGING SYSTEM ============================

  // 🔴 Flag inappropriate content (Users can report content)
  Future<void> flagContent(String docId, String userEmail) async {
    try {
      await _db.collection('help_requests').doc(docId).update({
        'flaggedBy': FieldValue.arrayUnion([userEmail]),
        'flags': FieldValue.increment(1),
      });
      print("✅ Content flagged successfully!");
    } catch (e) {
      print("❌ Error flagging content: $e");
    }
  }

  // 🟢 Remove flag from content (Admins can unflag content)
  Future<void> unflagContent(String docId) async {
    try {
      await _db.collection('help_requests').doc(docId).update({
        'flaggedBy': [],
        'flags': 0,
      });
      print("✅ Content unflagged successfully!");
    } catch (e) {
      print("❌ Error unflagging content: $e");
    }
  }

  // ❌ Delete inappropriate content (Admins can remove flagged posts)
  Future<void> deleteFlaggedContent(String docId) async {
    try {
      await _db.collection('help_requests').doc(docId).delete();
      print("✅ Flagged content deleted successfully!");
    } catch (e) {
      print("❌ Error deleting flagged content: $e");
    }
  }

  // 🔎 Get all flagged content for admin review
  Stream<QuerySnapshot> getFlaggedContent() {
    return _db
        .collection('help_requests')
        .where('flags', isGreaterThan: 0) // Only show flagged content
        .orderBy('flags', descending: true) // Sort by most flagged
        .snapshots();
  }

  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    DocumentSnapshot userDoc =
        await _db.collection('users').doc(user.uid).get();
    return userDoc.exists && userDoc['role'] == 'admin';
  }
}
