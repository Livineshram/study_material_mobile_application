import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String userEmail = '';
  String displayName = '';

  @override
  void initState() {
    super.initState();
    loadUserDetails();
  }

  Future<void> loadUserDetails() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() => userEmail = currentUser.email ?? '');

      final userDoc = await _db.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        setState(() => displayName = userDoc.data()?['name'] ?? '');
      }
    }
  }

  Future<void> _onRefresh() async => await loadUserDetails();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Hub',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _buildProfileAvatar(),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 30),
              _buildQuickActionsHeader(),
              const SizedBox(height: 20),
              Expanded(child: _buildActionGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/profile'),
      child: CircleAvatar(
        backgroundColor: Colors.deepPurple[100],
        child: Text(
          userEmail.isNotEmpty ? userEmail[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '👋 Welcome back,',
          style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          displayName.isNotEmpty ? displayName : 'Student',
          style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple),
        ),
        const SizedBox(height: 4),
        Text(
          userEmail,
          style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildQuickActionsHeader() {
    return const Text(
      'Quick Access',
      style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
    );
  }

  Widget _buildActionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(
            icon: Icons.menu_book_rounded,
            title: 'Study Materials',
            color: Colors.deepPurple,
            route: '/materials'),
        _buildActionCard(
            icon: Icons.help_center_rounded,
            title: 'Help Desk',
            color: Colors.blue,
            route: '/help'),
        _buildActionCard(
            icon: Icons.forum_rounded,
            title: 'Chat',
            color: Colors.green,
            route: '/chat'),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.9), color.withOpacity(0.7)]),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 42, color: Colors.white),
                const SizedBox(height: 15),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
