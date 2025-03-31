import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ======================== GLOBAL CHAT ========================
  Future<void> sendMessage(
    String message,
    String senderEmail, // Should match user.email
    String chatType, // 'global' in your case
  ) async {
    await FirebaseFirestore.instance.collection('messages').add({
      'message': message,
      'sender': senderEmail,
      'timestamp': Timestamp.now(),
      'type': chatType,
    });
  }

  // Get messages for the global chat
  Stream<QuerySnapshot> getGlobalMessages() {
    return _db
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Add a reaction to a message
  Future<void> addReaction(
      String messageId, String userId, String reaction) async {
    try {
      DocumentReference messageRef = _db.collection('messages').doc(messageId);
      await messageRef.update({
        'reactions.$userId': reaction,
      });
    } catch (e) {
      print("❌ Error adding reaction: $e");
    }
  }

  // Block a user
  Future<void> blockUser(String blockerId, String blockedId) async {
    try {
      await _db.collection('blocked_users').add({
        'blocker': blockerId,
        'blocked': blockedId,
      });
    } catch (e) {
      print("❌ Error blocking user: $e");
    }
  }

  // Report inappropriate message
  Future<void> reportMessage(String messageId) async {
    try {
      await _db.collection('messages').doc(messageId).update({
        'reported': true,
      });
    } catch (e) {
      print("❌ Error reporting message: $e");
    }
  }

  // Update the message (for editing the message content)
  Future<void> updateMessage(String messageId, String newMessage) async {
    try {
      await _db.collection('messages').doc(messageId).update({
        'message': newMessage, // Update the message text
        'edited': true, // Optional: Mark as edited
        'timestamp': FieldValue.serverTimestamp(), // Update timestamp
      });
    } catch (e) {
      print("❌ Error updating message: $e");
    }
  }

  // Delete a message
  Future<void> deleteMessage(String docId) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception("User not authenticated");
      }

      final doc = await _db.collection('messages').doc(docId).get();
      if (!doc.exists) {
        throw Exception("Message does not exist");
      }

      final senderEmail = doc['sender']?.toString().toLowerCase();
      final currentEmail = user.email!.toLowerCase();

      if (senderEmail != currentEmail) {
        throw Exception("You can only delete your own messages");
      }

      await _db.collection('messages').doc(docId).delete();
    } catch (e) {
      print("Error deleting message: $e");
      rethrow;
    }
  }
}
