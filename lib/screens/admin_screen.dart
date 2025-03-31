import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:student_application/screens/login_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Logout Function with Confirmation Dialog
  Future<void> _confirmLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Logout", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  // Delete Study Material with Confirmation
  Future<void> _confirmDelete(
      String docId, String fileUrl, bool isMaterial) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete this item?"),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              if (isMaterial) {
                _deleteMaterial(docId, fileUrl);
              } else {
                _deleteHelpRequest(docId);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaterial(String docId, String fileUrl) async {
    try {
      await _storage.refFromURL(fileUrl).delete();
      await _firestore.collection('study_materials').doc(docId).delete();
      _showSnackbar("Material deleted successfully!", Colors.green);
    } catch (e) {
      _showSnackbar("Error deleting material: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _deleteHelpRequest(String docId) async {
    try {
      await _firestore.collection('help_requests').doc(docId).delete();
      _showSnackbar("Help request deleted!", Colors.green);
    } catch (e) {
      _showSnackbar("Error deleting request: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _unflagMaterial(String docId) async {
    try {
      await _firestore.collection('study_materials').doc(docId).update({
        'flagged': false,
        'flags': FieldValue.increment(-1),
        'flaggedBy': FieldValue.arrayRemove(['admin'])
      });
      _showSnackbar("Material unflagged successfully!", Colors.blue);
    } catch (e) {
      _showSnackbar("Error unflagging material: $e", Colors.red);
    }
  }

  Future<void> _unflagHelpRequest(String docId) async {
    try {
      await _firestore.collection('help_requests').doc(docId).update({
        'flagged': false,
        'flaggedBy': FieldValue.delete(),
      });
      _showSnackbar("Help request unflagged!", Colors.blue);
    } catch (e) {
      _showSnackbar("Error unflagging request!", Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Admin Dashboard"),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Study Materials", icon: Icon(Icons.book)),
              Tab(text: "Help Requests", icon: Icon(Icons.help)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFlaggedMaterialsList(),
            _buildFlaggedHelpRequestsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFlaggedMaterialsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('study_materials')
          .where('flagged', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final materials = snapshot.data!.docs;
        if (materials.isEmpty)
          return Center(child: Text("No flagged study materials"));

        return ListView.builder(
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final material = materials[index];
            final data = material.data() as Map<String, dynamic>;
            final docId = material.id;

            return Card(
              margin: EdgeInsets.all(8),
              color: Colors.red[50],
              child: ListTile(
                title: Text(data['title'] ?? "No title",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Uploader: ${data['uploader'] ?? 'Unknown'}"),
                    Text(
                        "Flags: ${(data['flags'] is List) ? data['flags'].length : 0}"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(docId, data['url'], true),
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => _unflagMaterial(docId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFlaggedHelpRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('help_requests')
          .where('flagged', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final requests = snapshot.data!.docs;
        if (requests.isEmpty)
          return Center(child: Text("No flagged help requests"));

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final docId = request.id;

            return Card(
              margin: EdgeInsets.all(8),
              color: Colors.orange[50],
              child: ListTile(
                title: Text(data['title'] ?? "No title",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Description: ${data['description'] ?? 'No description'}"),
                    Text(
                        "Flags: ${(data['flaggedBy'] is List) ? data['flaggedBy'].length : 0}"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(docId, "", false),
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => _unflagHelpRequest(docId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
