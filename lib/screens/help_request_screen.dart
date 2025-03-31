import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_application/services/firestore_service.dart';

class HelpRequestScreen extends StatefulWidget {
  @override
  _HelpRequestScreenState createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends State<HelpRequestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  Future<void> _postHelpRequest() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await _firestoreService.postHelpRequest(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
      );
      _titleController.clear();
      _descriptionController.clear();
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _handleLike(String docId, List<dynamic> likedBy) async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;

    try {
      if (likedBy.contains(userEmail)) {
        await _firestoreService.removeLike(docId);
      } else {
        await _firestoreService.likeRequest(docId);
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _handleFlag(String docId, List<dynamic> flaggedBy) async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;

    try {
      if (flaggedBy.contains(userEmail)) {
        await _firestoreService.removeFlag(docId);
      } else {
        await _firestoreService.flagRequest(docId);
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _deleteRequest(String docId) async {
    try {
      await _firestoreService.deleteHelpRequest(docId);
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message ?? 'Delete failed'}')),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic> requestData, String docId) {
    _titleController.text = requestData['title'];
    _descriptionController.text = requestData['description'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Help Request"),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'Description'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _firestoreService.updateHelpRequest(
                  docId,
                  _titleController.text.trim(),
                  _descriptionController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: Text('Help Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getHelpRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading requests'));
          }

          final requests = snapshot.data?.docs ?? [];
          if (requests.isEmpty) {
            return Center(child: Text('No requests found'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;

              return Card(
                margin: EdgeInsets.all(8),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (data['uploader'] == currentUser)
                            PopupMenuButton(
                              constraints: BoxConstraints(minWidth: 100),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Text("Edit"),
                                  onTap: () => _showEditDialog(data, docId),
                                ),
                                PopupMenuItem(
                                  child: Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                  onTap: () => _deleteRequest(docId),
                                ),
                              ],
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(data['description']),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.thumb_up),
                            color:
                                data['likedBy']?.contains(currentUser) ?? false
                                    ? Colors.blue
                                    : null,
                            onPressed: () => _handleLike(
                                docId, List.from(data['likedBy'] ?? [])),
                          ),
                          Text('${data['likedBy']?.length ?? 0}'),
                          SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons.flag),
                            color: data['flaggedBy']?.contains(currentUser) ??
                                    false
                                ? Colors.red
                                : null,
                            onPressed: () => _handleFlag(
                                docId, List.from(data['flaggedBy'] ?? [])),
                          ),
                          Text('${data['flaggedBy']?.length ?? 0}'),
                          Expanded(
                            child: Text(
                              'Posted by: ${data['uploader']}',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("New Help Request"),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Title'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: 'Description'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: _postHelpRequest,
                child: Text("Post"),
              ),
            ],
          ),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}
