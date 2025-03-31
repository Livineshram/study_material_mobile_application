import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StudyMaterialScreen extends StatefulWidget {
  @override
  _StudyMaterialScreenState createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploading = false;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;
      String userId = _auth.currentUser!.uid;
      String uploader = _auth.currentUser!.email ?? "Unknown";

      setState(() => _isUploading = true);

      TaskSnapshot uploadTask =
          await _storage.ref('study_materials/$userId/$fileName').putFile(file);
      String downloadUrl = await uploadTask.ref.getDownloadURL();

      await _firestore.collection('study_materials').add({
        'title': fileName,
        'url': downloadUrl,
        'uploader': uploader,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'flags': [],
        'comments': []
      });

      setState(() => _isUploading = false);
    }
  }

  void _toggleReaction(String docId, List reactions, String field) async {
    String userId = _auth.currentUser!.uid;
    final docRef = _firestore.collection('study_materials').doc(docId);

    if (reactions.contains(userId)) {
      await docRef.update({
        field: FieldValue.arrayRemove([userId])
      });
    } else {
      await docRef.update({
        field: FieldValue.arrayUnion([userId])
      });
    }
  }

  void _deleteMaterial(String docId, String uploaderId) async {
    String userId = _auth.currentUser!.uid;
    if (userId == uploaderId) {
      await _firestore.collection('study_materials').doc(docId).delete();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can only delete your own files!")));
    }
  }

  Future<void> _downloadFile(String url) async {
    final Uri fileUrl = Uri.parse(url);
    if (await canLaunchUrl(fileUrl)) {
      await launchUrl(fileUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Could not download file")),
      );
    }
  }

  Future<void> _addCommentDialog(String docId) async {
    TextEditingController _commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add a Comment"),
        content: TextField(
          controller: _commentController,
          decoration: InputDecoration(hintText: "Enter your comment"),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Submit"),
            onPressed: () async {
              if (_commentController.text.trim().isNotEmpty) {
                String userId = _auth.currentUser!.uid;
                String userEmail = _auth.currentUser!.email ?? "Anonymous";
                String comment = _commentController.text.trim();

                await _firestore
                    .collection('study_materials')
                    .doc(docId)
                    .update({
                  'comments': FieldValue.arrayUnion([
                    {'userId': userId, 'user': userEmail, 'comment': comment}
                  ])
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _deleteComment(String docId, Map<String, dynamic> comment) async {
    String userId = _auth.currentUser!.uid;
    if (comment['userId'] == userId) {
      await _firestore.collection('study_materials').doc(docId).update({
        'comments': FieldValue.arrayRemove([comment])
      });
    }
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search files...",
          prefixIcon: Icon(Icons.search),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Study Materials")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickAndUploadFile,
            child: _isUploading
                ? CircularProgressIndicator()
                : Text("Upload Study Material"),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search files...",
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('study_materials')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final materials = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'].toString().toLowerCase();
                  return title.contains(_searchQuery.toLowerCase());
                }).toList();

                if (materials.isEmpty) {
                  return Center(
                    child: Text("We don't have what you're looking for 😞"),
                  );
                }

                return ListView.builder(
                  itemCount: materials.length,
                  itemBuilder: (context, index) {
                    var material = materials[index];
                    var data = material.data() as Map<String, dynamic>;
                    String docId = material.id;
                    String uploaderId = data['userId'];
                    List likes = data['likes'] ?? [];
                    List flags = data['flags'] ?? [];
                    List comments = data['comments'] ?? [];
                    bool isLiked = likes.contains(_auth.currentUser!.uid);
                    bool isFlagged = flags.contains(_auth.currentUser!.uid);

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(data['title']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Uploaded by: ${data['uploader']}"),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.thumb_up,
                                    color: isLiked ? Colors.blue : Colors.grey,
                                  ),
                                  onPressed: () =>
                                      _toggleReaction(docId, likes, 'likes'),
                                ),
                                Text("${likes.length}"),
                                IconButton(
                                  icon: Icon(
                                    Icons.flag,
                                    color: isFlagged ? Colors.red : Colors.grey,
                                  ),
                                  onPressed: () =>
                                      _toggleReaction(docId, flags, 'flags'),
                                ),
                                Text("${flags.length}"),
                              ],
                            ),
                            TextButton(
                              child: Text("Download"),
                              onPressed: () => _downloadFile(data['url']),
                            ),
                            Text("Comments (${comments.length}):"),
                            ...comments
                                .map((comment) => ListTile(
                                      title: Text(comment['comment']),
                                      subtitle: Text(comment['user']),
                                      trailing: comment['userId'] ==
                                              _auth.currentUser!.uid
                                          ? IconButton(
                                              icon: Icon(Icons.delete),
                                              onPressed: () => _deleteComment(
                                                  docId, comment),
                                            )
                                          : null,
                                    ))
                                .toList(),
                            TextButton(
                              child: Text("Add a Comment"),
                              onPressed: () => _addCommentDialog(docId),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteMaterial(docId, uploaderId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
