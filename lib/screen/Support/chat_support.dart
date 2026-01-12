import 'package:eshop/authentication/user_data.dart';
import 'package:eshop/services/Support/chat_api.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Simple local message model used by this chat screen.
class Message {
  final String id;
  final String text;
  final bool isUser;
  DateTime timestamp;
  final List<String>? options;
  bool visible;
  // If set, this message was created locally and may later receive a server id
  String? remoteId;
  // optimistic send state
  bool pending;
  bool failed;

  Message({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.visible = true,
    this.options,
    this.remoteId,
    this.pending = false,
    this.failed = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();
}

class ChatSupportPage extends StatefulWidget {
  const ChatSupportPage({super.key});

  @override
  State<ChatSupportPage> createState() => _ChatSupportPageState();
}

class _ChatSupportPageState extends State<ChatSupportPage>
    with TickerProviderStateMixin {
  final List<Message> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _userdata = UserData();
  late String jwtToken;
  final String supportUserId = '689c239a4ebe358ebc725e68'; //
  late ChatApiService _chatApi;
  // Track locally-created messages that are pending server confirmation
  final Map<String, Message> _pendingLocalSends = {};

  bool _botTyping = false;
  String? _conversationId;
  final Set<String> _seenMessageIds = {};
  Timer? _pollingTimer;
  bool _backendAvailable = true;
  bool _isLoading = true;

  // Main menus and submenus (fallback for local bot)
  final List<String> _mainMenu = [
    'Issue placing an order',
    'Offers/Promotions',
  ];

  final List<String> _issuePlacingOrder = [
    'My store is temporarily unavailable',
    'Product not available',
    'Area out of service',
    'Go back to main menu',
  ];

  final Map<String, String> _topicResponses = {
    'Offers/Promotions':
        "You can view all the ongoing offers under 'Use Coupons' section on the checkout page.",
    'Order tracking and delivery status':
        "Track your order in 'My Orders' section.",
    'Payment issues and refunds': "Refunds are processed in 5–7 business days.",
    'Account and profile help':
        "You can update your profile info from the Profile section.",
    'Cancellation and returns': "Orders can be cancelled before dispatch.",
    'Product quality complaints':
        "Please report issues via 'My Orders > Report Issue'.",
    'Delivery address changes':
        "Address can be changed before confirming the order.",
    'App technical issues':
        "Try clearing app cache or updating to the latest version.",
    'My store is temporarily unavailable':
        'This could be due to maintenance or temporary issues. Please try again later or choose another nearby store.',
    'Product not available':
        'The product seems out of stock. Try again later or check similar products.',
    'Area out of service':
        'We are expanding our delivery areas. Please check again later or contact support for updates.',
  };

  @override
  void initState() {
    super.initState();
    _chatApi = ChatApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_userdata.isLoggedIn()) {
        final doLogin = await _showLoginDialog();
        if (doLogin == true) {
          Navigator.of(context).pushNamed('/login');
        } else {
          if (mounted) Navigator.of(context).pop();
        }
        return;
      }

      await _loadUserData();
      if (jwtToken.isNotEmpty) {
        _chatApi.setToken(jwtToken);
      }

      // Start in BOT mode by default (do not auto-connect to live agent).
      // The user can explicitly request 'Connect to Support Agent' from the bot menu.
      setState(() {
        _isLoading = false;
      });

      // Show the bot welcome message (ensure only shown once)
      if (_messages.isEmpty) {
        _addBotReply(
          "Hello! 👋 I'm WheelyBot, your virtual assistant. How may I help you today?",
          options: _mainMenu,
          delayMs: 200,
        );
      }
    });
  }

  Future<bool?> _showLoginDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text('Login Required'),
              ],
            ),
            content: Text(
              'You need to log in to connect with our support team.',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Log In'),
              ),
            ],
          ),
    );
  }

  Future<void> _loadUserData() async {
    final user = _userdata.getCurrentUser();
    setState(() {
      jwtToken = user?.token ?? '';
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSupportConversation() async {
    print('🚀 [ChatSupport] Initializing support conversation...');

    try {
      setState(() => _isLoading = true);

      print(
        '📞 [ChatSupport] Starting conversation with support user: $supportUserId',
      );
      final conversation = await _chatApi.startOrRetrieveConversation(
        supportUserId,
      );

      _conversationId = conversation['_id'];
      print('✅ [ChatSupport] Conversation established. ID: $_conversationId');

      print(
        '📥 [ChatSupport] Loading messages for conversation: $_conversationId',
      );
      final messages = await _chatApi.getMessages(_conversationId!);
      print('📨 [ChatSupport] Loaded ${messages.length} messages');

      for (final m in messages) {
        if (_seenMessageIds.contains(m['_id'])) {
          print('⏭️ [ChatSupport] Skipping duplicate message: ${m["_id"]}');
          continue;
        }

        _seenMessageIds.add(m['_id']);
        final senderId = m['senderId'] ?? m['sender'];
        final isUserMsg = (senderId != supportUserId);

        print(
          '📝 [ChatSupport] Message ${m["_id"]}: ${isUserMsg ? "USER" : "SUPPORT"} - ${m["body"]}',
        );

        final uiMsg = Message(
          id: m['_id'],
          text: m['body'] ?? '',
          isUser: isUserMsg,
          timestamp: DateTime.parse(
            m['createdAt'] ??
                m['timestamp'] ??
                DateTime.now().toIso8601String(),
          ),
        );
        _addMessage(uiMsg, animate: false);
      }

      print('✓ [ChatSupport] Marking all messages as read');
      await _chatApi.markAllMessagesAsRead(_conversationId!);

      if (_messages.isEmpty) {
        print('👋 [ChatSupport] No existing messages, showing welcome message');
        _addBotReply(
          "Hello! 👋 I'm WheelyBot, your virtual assistant. How may I help you today?",
          options: _mainMenu,
        );
      }

      setState(() {
        _backendAvailable = true;
        _isLoading = false;
      });

      print('⏰ [ChatSupport] Starting message polling (5s interval)');
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _fetchNewMessages();
      });
    } catch (e, stackTrace) {
      print('❌ [ChatSupport] Failed to initialize: $e');
      print('📍 [ChatSupport] Stack trace: $stackTrace');

      setState(() {
        _backendAvailable = false;
        _isLoading = false;
      });

      if (_messages.isEmpty) {
        print('⚠️ [ChatSupport] Using fallback bot mode');
        _addBotReply(
          "Hello! 👋 I'm WheelyBot, your virtual assistant. I'm currently working in offline mode. How may I help you today?",
          options: _mainMenu,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Using offline assistant mode')),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _fetchNewMessages() async {
    if (_conversationId == null) {
      print('⚠️ [ChatSupport] Cannot fetch messages: No conversation ID');
      return;
    }

    try {
      print('🔄 [ChatSupport] Polling for new messages...');
      final messages = await _chatApi.getMessages(_conversationId!);

      var addedCount = 0;
      for (final m in messages) {
        if (_seenMessageIds.contains(m['_id'])) continue;

        final serverId = m['_id'];
        final body = m['body'] ?? '';
        final senderId = m['senderId'] ?? m['sender'];
        final isUserMsg = (senderId != supportUserId);

        // If this is a user message and we have a pending local send with the
        // same body, reconcile it instead of adding a duplicate from server.
        if (isUserMsg) {
          Message? matched;
          String? matchedKey;
          _pendingLocalSends.forEach((k, v) {
            if (matched == null && v.text == body) {
              matched = v;
              matchedKey = k;
            }
          });

          if (matched != null && matchedKey != null) {
            matched!.pending = false;
            matched!.failed = false;
            matched!.remoteId = serverId;
            try {
              matched!.timestamp = DateTime.parse(
                m['createdAt'] ??
                    m['timestamp'] ??
                    DateTime.now().toIso8601String(),
              );
            } catch (_) {}
            _pendingLocalSends.remove(matchedKey);
            _seenMessageIds.add(serverId);
            // don't add duplicate - continue to next message
            setState(() {});
            continue;
          }
        }

        // Otherwise add the server message normally
        _seenMessageIds.add(serverId);

        print(
          '📨 [ChatSupport] New message ${m["_id"]}: ${isUserMsg ? "USER" : "SUPPORT"} - ${m["body"]}',
        );

        final uiMsg = Message(
          id: m['_id'],
          text: m['body'] ?? '',
          isUser: isUserMsg,
          timestamp: DateTime.parse(
            m['createdAt'] ??
                m['timestamp'] ??
                DateTime.now().toIso8601String(),
          ),
        );
        _addMessage(uiMsg);
        addedCount++;
      }

      if (addedCount > 0) {
        print('✅ [ChatSupport] Added $addedCount new messages');
        await _chatApi.markAllMessagesAsRead(_conversationId!);
      } else {
        print('➖ [ChatSupport] No new messages');
      }
    } catch (e) {
      print('❌ [ChatSupport] Failed to fetch new messages: $e');
    }
  }

  void _addMessage(Message message, {bool animate = true}) {
    message.visible = !animate;
    setState(() => _messages.add(message));

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (animate) {
      Future.delayed(Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() => message.visible = true);
        }
      });
    }
  }

  Future<void> _addBotReply(
    String text, {
    int delayMs = 600,
    List<String>? options,
  }) async {
    setState(() => _botTyping = true);
    _scrollToBottom();
    await Future.delayed(Duration(milliseconds: delayMs));
    setState(() => _botTyping = false);

    // Only append 'Connect to Support Agent' when the bot is showing the
    // issue-placing-order submenu. This keeps the connect option out of other
    // generic menus. Do not mutate the original list passed in.
    List<String>? finalOptions;
    if (options != null) {
      finalOptions = List<String>.from(options);
      const connectLabel = 'Connect to Support Agent';

      // Append connect option only when options match issue placing order items
      final bool isIssueSubmenu = options.any(
        (o) => _issuePlacingOrder.contains(o),
      );
      if (isIssueSubmenu) {
        if (!finalOptions.contains(connectLabel)) {
          finalOptions.add(connectLabel);
        } else if (finalOptions.last != connectLabel) {
          finalOptions.remove(connectLabel);
          finalOptions.add(connectLabel);
        }
      }
    }

    final botMessage = Message(
      text: text,
      isUser: false,
      options: finalOptions,
    );
    _addMessage(botMessage);
  }

  void _userSelectsOption(String option) {
    print('👆 [ChatSupport] User selected option: $option');

    final userMessage = Message(text: option, isUser: true, pending: false);
    // If we're going to send this to backend, mark pending and track it.
    if (_conversationId != null &&
        _backendAvailable &&
        option != 'Connect to Support Agent') {
      userMessage.pending = true;
      _pendingLocalSends[userMessage.id] = userMessage;
    }
    _addMessage(userMessage);

    // If user explicitly requests an agent, try to start a chat immediately
    if (option == 'Connect to Support Agent') {
      if (_conversationId != null && _backendAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are already connected to an agent.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      _startNewChatImmediate();
      return;
    }

    if (_conversationId != null && _backendAvailable) {
      _sendToBackend(option, localMessage: userMessage);
      return;
    }

    _handleLocalBotFlow(option);
  }

  void _handleLocalBotFlow(String option) {
    print('🤖 [ChatSupport] Handling with local bot: $option');

    if (option == 'Issue placing an order') {
      Future.delayed(Duration(milliseconds: 200), () {
        _addBotReply(
          'Which concern may I help you with?',
          delayMs: 600,
          options: _issuePlacingOrder,
        );
      });
      return;
    }

    if (option == 'Offers/Promotions') {
      Future.delayed(Duration(milliseconds: 200), () {
        _addBotReply(
          "You can view all the ongoing offers under 'Use Coupons' section on the checkout page.",
          delayMs: 600,
          options: ['Go back to main menu'],
        );
      });
      return;
    }

    if (option == 'Go back to main menu') {
      Future.delayed(Duration(milliseconds: 150), () {
        _addBotReply(
          'How may I help you today?',
          delayMs: 600,
          options: _mainMenu,
        );
      });
      return;
    }

    if (_topicResponses.containsKey(option)) {
      final reply = _topicResponses[option]!;
      Future.delayed(Duration(milliseconds: 150), () {
        _addBotReply(reply, delayMs: 600, options: ['Go back to main menu']);
      });
      return;
    }

    Future.delayed(
      Duration(milliseconds: 150),
      () => _addBotReply(
        'Thank you for your message. Our support team will get back to you shortly.',
        delayMs: 600,
        options: ['Go back to main menu'],
      ),
    );
  }

  Future<void> _sendToBackend(String text, {Message? localMessage}) async {
    print('📤 [ChatSupport] Sending to backend: $text');

    try {
      // If caller provided the local message, ensure it's tracked as pending
      if (localMessage != null) {
        localMessage.pending = true;
        localMessage.failed = false;
        _pendingLocalSends[localMessage.id] = localMessage;
        setState(() {});
      }

      final response = await _chatApi.sendMessage(_conversationId!, text);
      final serverId = response['id'] ?? response['_id'];
      final serverTs = response['createdAt'] ?? response['timestamp'];
      print('✅ [ChatSupport] Message sent successfully: $serverId');

      // If caller passed the localMessage, reconcile it directly
      if (localMessage != null) {
        localMessage.pending = false;
        localMessage.failed = false;
        localMessage.remoteId = serverId?.toString();
        if (serverTs != null) {
          try {
            localMessage.timestamp = DateTime.parse(serverTs);
          } catch (_) {}
        }
        _pendingLocalSends.remove(localMessage.id);
        if (serverId != null) _seenMessageIds.add(serverId.toString());
        setState(() {});
      } else {
        // Fallback: attempt to match by text if no localMessage was supplied
        Message? matched;
        String? matchedKey;
        _pendingLocalSends.forEach((k, v) {
          if (matched == null && v.text == text) {
            matched = v;
            matchedKey = k;
          }
        });

        if (matched != null && matchedKey != null) {
          matched!.pending = false;
          matched!.failed = false;
          matched!.remoteId = serverId?.toString();
          if (serverTs != null) {
            try {
              matched!.timestamp = DateTime.parse(serverTs);
            } catch (_) {}
          }
          _pendingLocalSends.remove(matchedKey);
          if (serverId != null) _seenMessageIds.add(serverId.toString());
          setState(() {});
        }
      }

      await _chatApi.markAllMessagesAsRead(_conversationId!);
      print('✓ [ChatSupport] Messages marked as read');
    } catch (e) {
      print('❌ [ChatSupport] Failed to send message: $e');

      if (mounted) {
        // Mark any matching pending local message as failed
        Message? matched;
        String? matchedKey;
        _pendingLocalSends.forEach((k, v) {
          if (matched == null && v.text == text) {
            matched = v;
            matchedKey = k;
          }
        });
        if (matched != null && matchedKey != null) {
          matched!.pending = false;
          matched!.failed = true;
          _pendingLocalSends.remove(matchedKey);
          setState(() {});
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to send message')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                if (matched != null) {
                  _retrySend(matched!);
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _retrySend(Message message) async {
    // mark as pending and attempt resend
    message.pending = true;
    message.failed = false;
    _pendingLocalSends[message.id] = message;
    setState(() {});
    if (_conversationId != null && _backendAvailable) {
      await _sendToBackend(message.text, localMessage: message);
    } else {
      // immediate fail if backend is not available
      message.pending = false;
      message.failed = true;
      _pendingLocalSends.remove(message.id);
      setState(() {});
    }
  }

  Future<void> _sendCustomMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    print('💬 [ChatSupport] User typing custom message: $trimmed');
    _messageController.clear();

    final userMessage = Message(text: trimmed, isUser: true, pending: true);
    // Track as a pending local send so we can reconcile when server echoes arrive
    _pendingLocalSends[userMessage.id] = userMessage;
    _addMessage(userMessage);

    if (_conversationId != null && _backendAvailable) {
      await _sendToBackend(trimmed, localMessage: userMessage);
    } else {
      print('⚠️ [ChatSupport] Backend unavailable, using local bot');
      // mark as failed immediately when no backend
      userMessage.pending = false;
      userMessage.failed = true;
      _pendingLocalSends.remove(userMessage.id);
      setState(() {});
      _handleLocalBotFlow(trimmed);
    }
  }

  Future<void> _endConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.red.shade600),
                SizedBox(width: 8),
                Text('End Chat?'),
              ],
            ),
            content: Text(
              _backendAvailable
                  ? 'Are you sure you want to end this conversation? You can start a new chat anytime.'
                  : 'This will clear your current chat session with the bot.',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('End Chat', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    _pollingTimer?.cancel();

    try {
      if (_backendAvailable && _conversationId != null) {
        await _chatApi.markAllMessagesAsRead(_conversationId!);
      }
    } catch (e) {
      print('Error while ending conversation: $e');
    }

    setState(() {
      _conversationId = null;
      _messages.clear();
      _seenMessageIds.clear();
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Chat ended successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Show welcome message again after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _messages.isEmpty) {
          _addBotReply(
            "Hello! 👋 I'm WheelyBot, your virtual assistant. ${_backendAvailable ? 'How may I help you today?' : 'I\'m currently working in offline mode. How may I help you today?'}",
            options: _mainMenu,
            delayMs: 400,
          );
        }
      });
    }
  }

  // Start a new chat without confirmation (used when user taps "Connect to Support Agent")
  Future<void> _startNewChatImmediate() async {
    _pollingTimer?.cancel();

    setState(() {
      _messages.clear();
      _seenMessageIds.clear();
      _conversationId = null;
      _isLoading = true;
    });

    // Try to initialize conversation; _initSupportConversation will fallback to bot on failure
    try {
      await _initSupportConversation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Attempting to connect to agent'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Immediate start failed: $e');
      setState(() {
        _isLoading = false;
        _backendAvailable = false;
      });
      _addBotReply(
        'Agents are currently unavailable — I can help in the meantime.',
        options: _mainMenu,
      );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Message message, int index) {
    final isUser = message.isUser;
    final radius = Radius.circular(18);

    return AnimatedOpacity(
      duration: Duration(milliseconds: 400),
      opacity: message.visible ? 1 : 0,
      curve: Curves.easeIn,
      child: AnimatedSlide(
        duration: Duration(milliseconds: 400),
        offset: message.visible ? Offset.zero : Offset(0, 0.1),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: Row(
                mainAxisAlignment:
                    isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isUser) ...[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(
                          Icons.support_agent,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isUser
                                ? Colors.blue.shade600
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.only(
                          topLeft: isUser ? radius : Radius.circular(4),
                          topRight: isUser ? Radius.circular(4) : radius,
                          bottomLeft: radius,
                          bottomRight: radius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'WheelyBot',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          Text(
                            message.text,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isUser
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                ),
                              ),
                              if (isUser && message.pending) ...[
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white70,
                                    ),
                                  ),
                                ),
                              ] else if (isUser && message.failed) ...[
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _retrySend(message),
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ] else if (isUser) ...[
                                SizedBox(width: 6),
                                Text(
                                  ' ✓✓',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isUser) ...[
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade600,
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isUser &&
                message.options != null &&
                message.options!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: 52,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      message.options!
                          .map(
                            (option) => Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _userSelectsOption(option),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.blue.shade400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade50,
              child: Icon(
                Icons.support_agent,
                size: 20,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                SizedBox(width: 5),
                _dot(200),
                SizedBox(width: 5),
                _dot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      onEnd: () {
        if (_botTyping && mounted) {
          Future.delayed(Duration(milliseconds: delay), () {
            if (mounted) setState(() {});
          });
        }
      },
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: true,

        title: Row(
          children: [
            // Title content takes all available width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Customer Support',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _backendAvailable ? Colors.green : Colors.orange,
                        ),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _backendAvailable
                              ? 'Online • Available now'
                              : 'Offline • Bot assistant',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          if (_conversationId != null && _backendAvailable)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ElevatedButton.icon(
                onPressed: () async => await _endConversation(),
                icon: Icon(Icons.close, size: 18, color: Colors.white),
                label: Text(
                  "End Chat",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Connecting to support...',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait a moment',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  if (!_backendAvailable)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade50,
                            Colors.orange.shade100,
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              size: 18,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bot Assistant Mode',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Your assistant is working offline',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child:
                        _messages.isEmpty && !_botTyping
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.support_agent,
                                      size: 50,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Welcome to Support',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'We\'re here to help you',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              itemCount:
                                  _messages.length + (_botTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < _messages.length) {
                                  return _buildMessageBubble(
                                    _messages[index],
                                    index,
                                  );
                                }
                                return _buildTypingIndicator();
                              },
                            ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: 'Type your message...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  style: TextStyle(fontSize: 15),
                                  maxLines: null,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onSubmitted: (v) => _sendCustomMessage(v),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.blue.shade700,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap:
                                      () => _sendCustomMessage(
                                        _messageController.text,
                                      ),
                                  customBorder: CircleBorder(),
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
