import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  final Function(bool) toggleTheme;

  ProfileScreen({required this.toggleTheme});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _nameController = TextEditingController();

  String userEmail = '';
  String displayName = '';
  bool _isLoading = true;
  bool _darkMode = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward(); // Start animation

    loadUserDetails(); // Load user details
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void loadUserDetails() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        setState(() {
          userEmail = currentUser.email ?? '';
        });

        final userDoc =
            await _db.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          setState(() {
            displayName = userDoc.data()?['name'] ?? '';
            _nameController.text = displayName;
            _isLoading = false;
          });
        } else {
          _showErrorMessage('User details not found.');
        }
      } else {
        _showErrorMessage('User is not logged in.');
      }
    } catch (e) {
      _showErrorMessage('Error loading user details: $e');
    }
  }

  void _updateName() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _db.collection('users').doc(currentUser.uid).update({
          'name': _nameController.text.trim(),
        });
        setState(() {
          displayName = _nameController.text.trim();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Name updated successfully!'),
        ));
      }
    } catch (e) {
      _showErrorMessage('Error updating name: $e');
    }
  }

  void _toggleDarkMode(bool value) {
    setState(() {
      _darkMode = value;
    });
    widget.toggleTheme(_darkMode);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blueGrey[200],
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    SizedBox(height: 15),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 5),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Enter your name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _updateName,
                              icon: Icon(Icons.update),
                              label: Text('Update Name'),
                            ),
                            SizedBox(height: 15),
                            Text(
                              'Email: $userEmail',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ListTile(
                      title: Text(
                        'Dark Mode',
                        style: TextStyle(fontSize: 18),
                      ),
                      trailing: Switch(
                        value: _darkMode,
                        onChanged: _toggleDarkMode,
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.logout),
                      label: Text('Log Out'),
                      onPressed: () async {
                        await _auth.signOut();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
