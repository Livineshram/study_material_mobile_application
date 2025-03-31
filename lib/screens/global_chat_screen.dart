import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:student_application/services/chat_service.dart';

class GlobalChatScreen extends StatefulWidget {
  @override
  _GlobalChatScreenState createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final FocusNode _focusNode = FocusNode();

  String? _editingMessageId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final user = _auth.currentUser;

    try {
      if (user?.email == null) throw Exception("User not authenticated");

      if (_editingMessageId != null) {
        await _chatService.updateMessage(
            _editingMessageId!, _controller.text.trim());
      } else {
        await _chatService.sendMessage(
          _controller.text.trim(),
          user!.email!,
          'global',
        );
      }

      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackbar('Failed to send message: ${e.toString()}');
    } finally {
      setState(() {
        _isSending = false;
        _editingMessageId = null;
      });
    }
  }

  void _startEditing(String messageId, String messageText) {
    if (_auth.currentUser?.email == null) return;

    setState(() => _editingMessageId = messageId);
    _controller.text = messageText;
    _focusNode.requestFocus();
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
    } catch (e) {
      _showErrorSnackbar('Failed to delete message: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('HH:mm').format(timestamp.toDate().toLocal());
  }

  String _formatFullDate(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy HH:mm')
        .format(timestamp.toDate().toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserEmail = _auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Chat'),
        systemOverlayStyle:
            isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getGlobalMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Start the conversation!',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>? ?? {};
                    final messageId = message.id;
                    final isCurrentUser = data['sender'] == currentUserEmail;

                    return _ChatBubble(
                      message: data['message'],
                      sender: data['sender'],
                      timestamp: data['timestamp'] as Timestamp,
                      isCurrentUser: isCurrentUser,
                      isDarkMode: isDarkMode,
                      onEdit: () => _startEditing(messageId, data['message']),
                      onDelete: () => _deleteMessage(messageId),
                    );
                  },
                );
              },
            ),
          ),
          _ChatInputField(
            controller: _controller,
            focusNode: _focusNode,
            isSending: _isSending,
            isEditing: _editingMessageId != null,
            onSend: _sendMessage,
            onCancelEdit: () => setState(() => _editingMessageId = null),
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final String sender;
  final Timestamp timestamp;
  final bool isCurrentUser;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChatBubble({
    required this.message,
    required this.sender,
    required this.timestamp,
    required this.isCurrentUser,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? (isDarkMode ? Colors.blue[800] : Colors.blue[100])
              : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isCurrentUser ? const Radius.circular(16) : Radius.zero,
            bottomRight:
                isCurrentUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Text(
                sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                ),
              ),
            Text(
              message,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showTimeTooltip(context),
                    child: Text(
                      DateFormat('HH:mm').format(timestamp.toDate().toLocal()),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ),
                if (isCurrentUser)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 20),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading:
                              Icon(Icons.delete, color: Colors.red, size: 20),
                          title: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeTooltip(BuildContext context) {
    final fullDate =
        DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate().toLocal());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fullDate),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isEditing;
  final VoidCallback onSend;
  final VoidCallback onCancelEdit;
  final bool isDarkMode;

  const _ChatInputField({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isEditing,
    required this.onSend,
    required this.onCancelEdit,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 3,
              minLines: 1,
              enabled: !isSending,
              decoration: InputDecoration(
                hintText:
                    isEditing ? 'Edit your message...' : 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: isEditing
                    ? IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: onCancelEdit,
                        color: Colors.red,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isSending
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      isEditing ? Icons.check : Icons.send,
                      color: isDarkMode ? Colors.white : Colors.blue,
                    ),
                    onPressed: onSend,
                  ),
          ),
        ],
      ),
    );
  }
}
