import 'dart:async';
import 'dart:io';

import 'package:eshop/authentication/user_data.dart';
import 'package:eshop/services/Support/chat_api.dart';
import 'package:eshop/services/Order/order_api_service.dart'; // Ensure this import exists
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Local message model used by this chat screen.
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
  // Image support
  final String? imageUrl;
  final File? localImage;

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
    this.imageUrl,
    this.localImage,
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
  String? _activeReturnId;

  // --- HARDCODED SUPPORT ID (Preserved for General Support) ---
  final String supportUserId = '689c239a4ebe358ebc725e68';

  late ChatApiService _chatApi;
  final Map<String, Message> _pendingLocalSends = {};

  // Image Picker
  final ImagePicker _picker = ImagePicker();

  // --- RETURN FLOW STATE ---
  // Maps option text (e.g., "Order #123...") to the actual data object
  final Map<String, Map<String, dynamic>> _optionToOrderMap = {};
  final Map<String, Map<String, dynamic>> _optionToItemMap = {};
  Map<String, dynamic>? _selectedOrderForReturn;

  bool _botTyping = false;
  String? _conversationId;
  final Set<String> _seenMessageIds = {};
  Timer? _pollingTimer;
  bool _backendAvailable = true;
  bool _isLoading = true;

  // Main menus and submenus
  final List<String> _mainMenu = [
    'Issue placing an order',
    'Offers/Promotions',
    'Damage or Support', // New Option
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

      setState(() {
        _isLoading = false;
      });

      // Show the bot welcome message
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

  // ------------------------------------------------------------------------
  // CONNECTION MANAGEMENT
  // ------------------------------------------------------------------------

  // 1. Standard Support (Connects to Hardcoded ID)
  Future<void> _initSupportConversation() async {
    print('🚀 [ChatSupport] Initializing Standard Support...');
    try {
      setState(() => _isLoading = true);

      // Connect to the generic support user
      final conversation = await _chatApi.startOrRetrieveConversation(
        supportUserId,
      );

      _conversationId = conversation['_id'];
      await _loadHistoryAndStartPolling();

      setState(() {
        _backendAvailable = true;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error init standard support: $e');
      _handleConnectionError(e, stackTrace);
    }
  }

  // 2. Return Support (Connects to ID from Return API)
  Future<void> _initChatWithId(String conversationId) async {
    print('🚀 [ChatSupport] Connecting to specific conversation: $conversationId');
    try {
      setState(() => _isLoading = true);

      _conversationId = conversationId;
      await _loadHistoryAndStartPolling();

      setState(() {
        _backendAvailable = true;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error connecting to chat ID: $e');
      _handleConnectionError(e, stackTrace);
    }
  }

  void _handleConnectionError(dynamic e, StackTrace stackTrace) {
    print('❌ [ChatSupport] Failed to initialize: $e');
    print('📍 [ChatSupport] Stack trace: $stackTrace');

    setState(() {
      _backendAvailable = false;
      _isLoading = false;
    });

    if (_messages.isEmpty) {
      _addBotReply(
        "Hello! 👋 I'm WheelyBot. I'm currently working in offline mode. How may I help you today?",
        options: _mainMenu,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection failed. Using offline mode.")));
    }
  }

  Future<void> _loadHistoryAndStartPolling() async {
    if (_conversationId == null) return;

    // Load initial history
    final messages = await _chatApi.getMessages(_conversationId!);
    for (final m in messages) {
      _processServerMessage(m, animate: false);
    }

    // Mark as read
    await _chatApi.markAllMessagesAsRead(_conversationId!);

    // Start Polling
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchNewMessages();
    });
  }

  Future<void> _fetchNewMessages() async {
    if (_conversationId == null) return;

    try {
      final messages = await _chatApi.getMessages(_conversationId!);

      var addedCount = 0;
      for (final m in messages) {
        if (_processServerMessage(m)) {
          addedCount++;
        }
      }

      if (addedCount > 0) {
        await _chatApi.markAllMessagesAsRead(_conversationId!);
      }
    } catch (e) {
      print('❌ [ChatSupport] Failed to fetch new messages: $e');
    }
  }

  // Returns true if message was added
  bool _processServerMessage(dynamic m, {bool animate = true}) {
    if (_seenMessageIds.contains(m['_id'])) return false;

    final serverId = m['_id'];
    final body = m['body'] ?? '';
    final senderId = m['senderId'] ?? m['sender'];
    final currentUserId = UserData().getPhone(); // Adjust based on your auth model

    // Determine if message is from the user or support
    // Logic: If sender != me AND sender != hardcoded_support (optional check), it's likely incoming support
    bool isUserMsg = true;

    // Check 1: Explicit Map check (common in populated responses)
    if (senderId is Map) {
      if (senderId['_id'] != currentUserId) isUserMsg = false;
    }
    // Check 2: String ID check
    else if (senderId is String) {
      if (senderId != currentUserId && senderId != supportUserId) isUserMsg = false;
    }
    // Check 3: Explicit support ID check
    if (senderId == supportUserId) isUserMsg = false;

    final imgUrl = m['image'] ?? m['attachmentUrl'];

    // Reconcile pending local messages (Optimistic UI)
    if (isUserMsg && imgUrl == null) {
      Message? matched;
      String? matchedKey;
      _pendingLocalSends.forEach((k, v) {
        if (matched == null && v.text == body && v.localImage == null) {
          matched = v;
          matchedKey = k;
        }
      });

      if (matched != null && matchedKey != null) {
        matched!.pending = false;
        matched!.failed = false;
        matched!.remoteId = serverId;
        try {
          matched!.timestamp = DateTime.parse(m['createdAt'] ?? DateTime.now().toIso8601String());
        } catch (_) {}
        _pendingLocalSends.remove(matchedKey);
        _seenMessageIds.add(serverId);
        if (mounted) setState(() {});
        return false; // Already shown locally
      }
    }

    _seenMessageIds.add(serverId);

    final uiMsg = Message(
      id: m['_id'],
      text: m['body'] ?? '',
      isUser: isUserMsg,
      imageUrl: imgUrl,
      timestamp: DateTime.parse(
        m['createdAt'] ?? m['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
    _addMessage(uiMsg, animate: animate);
    return true;
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

    List<String>? finalOptions;
    if (options != null) {
      finalOptions = List<String>.from(options);
      const connectLabel = 'Connect to Support Agent';

      // Smartly add "Connect to Support Agent" if we are in the issue placing order menu
      final bool isIssueSubmenu = options.any((o) => _issuePlacingOrder.contains(o));
      if (isIssueSubmenu) {
        if (!finalOptions.contains(connectLabel)) {
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

  // ------------------------------------------------------------------------
  // USER INTERACTION FLOWS
  // ------------------------------------------------------------------------

  void _userSelectsOption(String option) {
    print('👆 [ChatSupport] User selected option: $option');

    final userMessage = Message(text: option, isUser: true, pending: false);

    // 1. DYNAMIC ORDER SELECTION
    if (_optionToOrderMap.containsKey(option)) {
      _addMessage(userMessage);
      _handleOrderSelected(option);
      return;
    }

    // 2. DYNAMIC ITEM SELECTION
    if (_optionToItemMap.containsKey(option)) {
      _addMessage(userMessage);
      _handleItemSelected(option);
      return;
    }

    // 3. MAIN MENU: DAMAGE OR SUPPORT
    if (option == 'Damage or Support') {
      _addMessage(userMessage);
      _handleDamageOrSupportFlow();
      return;
    }

    // 4. EXPLICIT AGENT CONNECTION (General)
    if (option == 'Connect to Support Agent') {
      if (_conversationId != null && _backendAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Already connected.")));
        return;
      }
      _addMessage(userMessage);
      _initSupportConversation(); // Connects to hardcoded ID
      return;
    }

    // 5. IF ALREADY CONNECTED, SEND AS TEXT
    if (_conversationId != null && _backendAvailable) {
      _sendToBackend(option, localMessage: userMessage);
      return;
    }

    // 6. LOCAL BOT FALLBACK
    _addMessage(userMessage);
    _handleLocalBotFlow(option);
  }

  // --- RETURN FLOW: Step 1 (Fetch Orders) ---
  Future<void> _handleDamageOrSupportFlow() async {
    setState(() => _botTyping = true);
    try {
      final orders = await OrderService.fetchUserOrders();
      // Get top 3
      final recentOrders = orders.take(3).toList();

      if (recentOrders.isEmpty) {
        setState(() => _botTyping = false);
        _addBotReply("I couldn't find any recent orders.", options: ['Connect to Support Agent', 'Go back to main menu']);
        return;
      }

      _optionToOrderMap.clear();
      List<String> orderOptions = [];

      for (var order in recentOrders) {
        final amount = order['finalAmount'] ?? order['totalAmount'] ?? 0;
        final items = order['items'] as List? ?? [];
        final orderId = order['orderNumber'] ?? order['invoiceNumber'] ?? 'Order';

        // Create label: "SO/1234 - ₹500 (3 Items)"
        String label = "$orderId - ₹$amount (${items.length} Items)";

        _optionToOrderMap[label] = order;
        orderOptions.add(label);
      }

      setState(() => _botTyping = false);
      _addBotReply("Please select the order related to your issue:", options: orderOptions);

    } catch (e) {
      setState(() => _botTyping = false);
      _addBotReply("Failed to fetch orders.", options: ['Connect to Support Agent']);
    }
  }

  // --- RETURN FLOW: Step 2 (Select Item) ---
  void _handleOrderSelected(String optionKey) {
    final order = _optionToOrderMap[optionKey];
    if (order == null) return;

    _selectedOrderForReturn = order;
    final items = order['items'] as List? ?? [];

    if (items.isEmpty) {
      _addBotReply("This order has no items.", options: ['Go back to main menu']);
      return;
    }

    if (items.length == 1) {
      _createReturnTicket(items[0]);
    } else {
      _optionToItemMap.clear();
      List<String> itemOptions = [];

      for (var row in items) {
        // DEBUG: See exactly what is inside the nested 'item' key
        print("📦 NESTED ITEM DATA: ${row['item']}");

        String name = 'Unknown Item';
        dynamic productData = row['item']; // Focus on the 'item' key seen in your screenshot

        // CASE A: The nested 'item' is a Map (Object)
        if (productData is Map) {
          // Check all possible name keys inside the nested object
          name = productData['itemName'] ??
              productData['name'] ??
              productData['productName'] ??
              productData['title'] ??
              productData['en_name'] ?? // Common in multilingual apps
              'Unknown Item';
        }
        // CASE B: The nested 'item' is just a String (ID)
        else if (productData is String) {
          name = "Item ID: $productData";
        }

        // CASE C: Fallback to root keys if nested lookup failed
        if (name == 'Unknown Item') {
          name = row['itemName'] ?? row['name'] ?? 'Unknown Item';
        }

        // If STILL unknown, show the quantity/price as a hint
        if (name == 'Unknown Item') {
          final price = row['salesPrice'] ?? row['price'] ?? 0;
          name = "Item (Price: ₹$price)";
        }

        // Ensure unique buttons
        while (_optionToItemMap.containsKey(name)) { name = "$name "; }

        _optionToItemMap[name] = row;
        itemOptions.add(name);
      }

      _addBotReply("Which item would you like to return?", options: itemOptions);
    }
  }

  // --- RETURN FLOW: Step 3 (Confirm Item) ---
  void _handleItemSelected(String optionKey) {
    final item = _optionToItemMap[optionKey];
    if (item != null) {
      _createReturnTicket(item);
    }
  }

  // --- RETURN FLOW: Step 4 (API Call & Connect) ---
  Future<void> _createReturnTicket(Map<String, dynamic> item) async {
    if (_selectedOrderForReturn == null) return;

    setState(() => _botTyping = true);

    // Extract Order ID
    final orderId = _selectedOrderForReturn!['_id'] ?? _selectedOrderForReturn!['id'];

    // Extract Item ID (handle nested 'item' object if present)
    String itemId = item['itemId'] ?? item['_id'] ?? item['id'] ?? '';
    // Handle the specific structure seen in your logs: item -> _id
    if (item.containsKey('item') && item['item'] is Map) {
      itemId = item['item']['_id'] ?? itemId;
    }

    try {
      // Call the API
      final responseData = await _chatApi.createReturnRequest(
        orderId: orderId,
        itemId: itemId,
        reason: "Damaged item received",
        notes: "Reported via Chat Support",
      );

      final conversationId = responseData['conversation'];
      final returnId = responseData['_id'];

      setState(() {
        _botTyping = false;
        _activeReturnId = returnId; // Save ID for image uploads
      });

      // Check if this was a new one or an existing one
      // If we got here despite a 409, it means the API returned the existing data (Smart Handling)
      _addBotReply(
          "I found your return request #$returnId. Connecting you to the specialist now..."
      );

      // Connect to the specific conversation
      if (conversationId != null) {
        _initChatWithId(conversationId);
      } else {
        _initSupportConversation();
      }

    } catch (e) {
      setState(() => _botTyping = false);
      print("❌ Return handling error: $e");

      // Handle the "Already Exists" case gracefully
      if (e.toString().contains("RETURN_EXISTS") || e.toString().contains("409")) {
        _addBotReply(
            "It looks like you already have an open return request for this item. I'm connecting you to our support team to assist you with it."
        );
        _initSupportConversation(); // Connect to general support to discuss the existing return
      } else {
        // Generic error
        _addBotReply("I encountered an issue creating the return. Connecting you to a human agent.");
        _initSupportConversation();
      }
    }
  }

  void _handleLocalBotFlow(String option) {
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
    try {
      if (localMessage != null) {
        localMessage.pending = true;
        localMessage.failed = false;
        _pendingLocalSends[localMessage.id] = localMessage;
        setState(() {});
      }

      final response = await _chatApi.sendMessage(_conversationId!, text);
      final serverId = response['id'] ?? response['_id'];
      final serverTs = response['createdAt'] ?? response['timestamp'];

      if (localMessage != null) {
        localMessage.pending = false;
        localMessage.remoteId = serverId?.toString();
        if (serverTs != null) {
          localMessage.timestamp = DateTime.parse(serverTs);
        }
        _pendingLocalSends.remove(localMessage.id);
        if (serverId != null) _seenMessageIds.add(serverId.toString());
        setState(() {});
      } else {
        // Fallback match by text
        // (Simplified logic here)
      }

      await _chatApi.markAllMessagesAsRead(_conversationId!);
    } catch (e) {
      if (localMessage != null) {
        localMessage.pending = false;
        localMessage.failed = true;
        setState(() {});
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send")));
    }
  }

  Future<void> _retrySend(Message message) async {
    message.pending = true;
    message.failed = false;
    _pendingLocalSends[message.id] = message;
    setState(() {});

    if (_conversationId != null && _backendAvailable) {
      await _sendToBackend(message.text, localMessage: message);
    } else {
      message.pending = false;
      message.failed = true;
      setState(() {});
    }
  }

  Future<void> _sendCustomMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _messageController.clear();

    final userMessage = Message(text: trimmed, isUser: true, pending: true);
    _pendingLocalSends[userMessage.id] = userMessage;
    _addMessage(userMessage);

    if (_conversationId != null && _backendAvailable) {
      await _sendToBackend(trimmed, localMessage: userMessage);
    } else {
      userMessage.pending = false;
      userMessage.failed = true;
      _pendingLocalSends.remove(userMessage.id);
      setState(() {});
      _handleLocalBotFlow(trimmed);
    }
  }

  // ------------------------------------------------------------------------
  // IMAGE PICKING & UPLOAD
  // ------------------------------------------------------------------------

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Upload Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(Icons.camera_alt, 'Camera', ImageSource.camera),
                _buildOption(Icons.photo_library, 'Gallery', ImageSource.gallery),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        try {
          final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
          if (image != null) {
            _sendImageMessage(File(image.path));
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade50,
            child: Icon(icon, color: Colors.blue.shade600, size: 28),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _sendImageMessage(File imageFile) async {
    if (_conversationId == null || !_backendAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please connect to an agent first.")));
      return;
    }

    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final userMessage = Message(
      id: localId,
      text: 'Sent an image',
      isUser: true,
      pending: true,
      localImage: imageFile,
    );

    _addMessage(userMessage);

    try {
      // --- FIX START: Choose the correct API based on context ---
      if (_activeReturnId != null) {
        // We are in a return flow, upload as EVIDENCE
        await _chatApi.uploadReturnImage(_activeReturnId!, imageFile);
      } else {
        // Standard chat attachment
        await _chatApi.sendImageMessage(_conversationId!, imageFile);
      }
      // --- FIX END ---

      setState(() { userMessage.pending = false; });
    } catch (e) {
      setState(() {
        userMessage.pending = false;
        userMessage.failed = true;
      });
      print("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to upload image")));
    }
  }

  Future<void> _endConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: Colors.red.shade600),
            SizedBox(width: 8),
            Text('End Chat?'),
          ],
        ),
        content: Text(
          _backendAvailable
              ? 'Are you sure you want to end this conversation?'
              : 'This will clear your current chat session with the bot.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text('End Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _pollingTimer?.cancel();
    if (_backendAvailable && _conversationId != null) {
      try { await _chatApi.markAllMessagesAsRead(_conversationId!); } catch (_) {}
    }

    setState(() {
      _conversationId = null;
      _activeReturnId = null; // <--- RESET THIS
      _messages.clear();
      _seenMessageIds.clear();
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat ended successfully'), backgroundColor: Colors.green.shade600),
      );
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _messages.isEmpty) {
          _addBotReply(
            "Hello! 👋 I'm WheelyBot, your virtual assistant. How may I help you today?",
            options: _mainMenu,
            delayMs: 400,
          );
        }
      });
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

  // ------------------------------------------------------------------------
  // UI BUILDERS
  // ------------------------------------------------------------------------

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
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade50),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.support_agent, size: 20, color: Colors.blue.shade700),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue.shade600 : Colors.grey.shade100,
                        borderRadius: BorderRadius.only(
                          topLeft: isUser ? radius : Radius.circular(4),
                          topRight: isUser ? Radius.circular(4) : radius,
                          bottomLeft: radius,
                          bottomRight: radius,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('WheelyBot', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue.shade700)),
                            ),

                          // --- IMAGE DISPLAY ---
                          if (message.localImage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(message.localImage!, height: 180, width: 180, fit: BoxFit.cover),
                              ),
                            )
                          else if (message.imageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  message.imageUrl!,
                                  height: 180,
                                  width: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_,__,___) => Container(color: Colors.grey[300], height: 180, width: 180, child: Icon(Icons.broken_image)),
                                ),
                              ),
                            ),

                          if (message.text.isNotEmpty && message.text != 'Sent an image')
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),

                          SizedBox(height: 4),
                          // Time & Status
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 11, color: isUser ? Colors.white70 : Colors.grey.shade600),
                              ),
                              if (isUser && message.pending) ...[
                                SizedBox(width: 8),
                                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white70))),
                              ] else if (isUser && message.failed) ...[
                                SizedBox(width: 8),
                                Icon(Icons.error_outline, size: 14, color: Colors.white70),
                              ] else if (isUser) ...[
                                SizedBox(width: 6),
                                Text(' ✓✓', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isUser) ...[
                    SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.shade600,
                      child: Icon(Icons.person, size: 20, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            if (!isUser && message.options != null && message.options!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 52, right: 12, top: 8, bottom: 8),
                child: Column(
                  children: message.options!.map((option) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _userSelectsOption(option),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(option, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500))),
                            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue.shade400),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
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
          CircleAvatar(radius: 18, backgroundColor: Colors.blue.shade50, child: Icon(Icons.support_agent, size: 20, color: Colors.blue.shade700)),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(0), SizedBox(width: 5), _dot(200), SizedBox(width: 5), _dot(400)]),
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
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.grey.shade600, shape: BoxShape.circle)),
      onEnd: () { if (_botTyping && mounted) Future.delayed(Duration(milliseconds: delay), () { if (mounted) setState(() {}); }); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87)),
            if (_backendAvailable) Text('Online • Available now', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          if (_conversationId != null && _backendAvailable)
            IconButton(icon: Icon(Icons.close, color: Colors.red), onPressed: _endConversation)
        ],
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : Column(
        children: [
          if (!_backendAvailable)
            Container(
              padding: EdgeInsets.all(10), color: Colors.orange.shade50,
              child: Row(children: [Icon(Icons.smart_toy, color: Colors.orange), SizedBox(width: 10), Text("Bot Assistant Mode", style: TextStyle(color: Colors.orange.shade900))]),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + (_botTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) return _buildMessageBubble(_messages[index], index);
                return _buildTypingIndicator();
              },
            ),
          ),
          // Input Area
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.add_photo_alternate, color: Colors.blue.shade600), onPressed: _showImagePickerModal),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(hintText: 'Type your message...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        onSubmitted: (v) => _sendCustomMessage(v),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendCustomMessage(_messageController.text),
                    child: CircleAvatar(backgroundColor: Colors.blue.shade600, child: Icon(Icons.send, color: Colors.white, size: 18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}