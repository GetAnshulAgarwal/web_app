import 'package:flutter/material.dart';
import 'dart:async';

import '../../utils/date_formatter.dart';
import '../../model/Support/support_message.dart';
import '../../model/Support/support_ticket.dart';
import '../../services/Support/support_api_service.dart';

class SupportChatScreen extends StatefulWidget {
  final SupportTicket ticket;
  final String? category;

  const SupportChatScreen({required this.ticket, this.category});

  @override
  _SupportChatScreenState createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  List<SupportMessage> messages = [];
  TextEditingController messageController = TextEditingController();
  ScrollController scrollController = ScrollController();
  bool isLoading = true;
  bool isSending = false;
  Timer? typingTimer;
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAllAsRead();
  }

  void _loadMessages() async {
    try {
      final loadedMessages = await SupportApiService.getMessages(
        widget.ticket.id,
      );
      setState(() {
        messages = loadedMessages.reversed.toList();
        isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
    }
  }

  void _markAllAsRead() async {
    try {
      await SupportApiService.markAllMessagesAsRead(widget.ticket.id);
    } catch (e) {
      // Handle error silently
    }
  }

  void _sendMessage() async {
    if (messageController.text.trim().isEmpty || isSending) return;

    final messageText = messageController.text.trim();
    messageController.clear();

    setState(() {
      isSending = true;
    });

    try {
      final newMessage = await SupportApiService.sendMessage(
        widget.ticket.id,
        messageText,
      );
      setState(() {
        messages.add(newMessage);
        isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        isSending = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support Chat'),
            Text(
              widget.ticket.subject,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Color(0xFF667EEA),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadMessages();
                  break;
                case 'close_ticket':
                  _showCloseTicketDialog();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'close_ticket',
                    child: Row(
                      children: [
                        Icon(Icons.close),
                        SizedBox(width: 8),
                        Text('Close Ticket'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Color(0xFF667EEA).withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF667EEA)),
                SizedBox(width: 8),
                Text(
                  'Status: ${widget.ticket.status.toUpperCase()} • Priority: ${widget.ticket.priority.toUpperCase()}',
                  style: TextStyle(
                    color: Color(0xFF667EEA),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child:
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
          ),

          // Typing Indicator
          if (isTyping)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Support is typing...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),

          // Message Input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF667EEA),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child:
                        isSending
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send your first message to get help from our support team',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          if (widget.category != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Category: ${widget.category!.toUpperCase()}',
                style: TextStyle(
                  color: Color(0xFF667EEA),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SupportMessage message) {
    final isFromUser = !message.isFromSupport;
    final isRead = message.readBy.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromUser) ...[
            CircleAvatar(
              backgroundColor: Color(0xFF667EEA),
              radius: 16,
              child: Icon(Icons.support_agent, color: Colors.white, size: 16),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromUser ? Color(0xFF667EEA) : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(isFromUser ? 16 : 4),
                  bottomRight: Radius.circular(isFromUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: TextStyle(
                      color: isFromUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormatter.formatMessageTime(message.createdAt),
                        style: TextStyle(
                          color: isFromUser ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (isFromUser) ...[
                        SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          color: isRead ? Color(0xFF48BB78) : Colors.white70,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isFromUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Color(0xFF48BB78),
              radius: 16,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  void _showCloseTicketDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Close Ticket'),
            content: Text(
              'Are you sure you want to close this support ticket? You can always create a new one if you need further assistance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ticket closed successfully')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Close Ticket'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    typingTimer?.cancel();
    super.dispose();
  }
}
