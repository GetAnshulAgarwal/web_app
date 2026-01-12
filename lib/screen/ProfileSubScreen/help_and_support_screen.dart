import 'package:flutter/material.dart';

import '../../authentication/user_data.dart';
import '../../services/Support/support_api_service.dart';
import '../Support/faq_screen.dart' show FAQScreen;
import '../Support/support_chat_screen.dart';
import '../Support/support_tickets_screen.dart';

class HelpSupportMainScreen extends StatefulWidget {
  @override
  _HelpSupportMainScreenState createState() => _HelpSupportMainScreenState();
}

class _HelpSupportMainScreenState extends State<HelpSupportMainScreen> {
  final UserData _userData = UserData();

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() {
    if (!SupportApiService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showLoginRequiredDialog();
        }
      });
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Login Required'),
              ],
            ),
            content: Text(
              'You need to be logged in to access support features. Please login to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to previous screen
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to login screen - adjust route as needed
                  // Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF667EEA),
                ),
                child: Text('Login'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support'),
        backgroundColor: Color(0xFF667EEA),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667EEA), Color(0xFF1A202C)],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.support_agent, size: 60, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'How can we help you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Get instant support or browse frequently asked questions',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // User Info Display (if authenticated)
                      if (SupportApiService.isAuthenticated)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Color(0xFF48BB78).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFF48BB78).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(0xFF48BB78),
                                radius: 16,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, ${_userData.getName()}!',
                                      style: TextStyle(
                                        color: Color(0xFF48BB78),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Phone: ${_userData.getPhone()}',
                                      style: TextStyle(
                                        color: Color(
                                          0xFF48BB78,
                                        ).withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: Color(0xFF48BB78),
                                size: 20,
                              ),
                            ],
                          ),
                        ),

                      // Authentication Status Check
                      if (!SupportApiService.isAuthenticated)
                        Container(
                          padding: EdgeInsets.all(16),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Authentication Required',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Please login to access live chat support',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionCard(
                              icon: Icons.chat_bubble_outline,
                              title: 'Live Chat',
                              subtitle:
                                  SupportApiService.isAuthenticated
                                      ? 'Chat with support'
                                      : 'Login required',
                              color: Color(0xFF48BB78),
                              onTap: () => _navigateToTickets(),
                              enabled: SupportApiService.isAuthenticated,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildQuickActionCard(
                              icon: Icons.help_outline,
                              title: 'FAQ',
                              subtitle: 'Common questions',
                              color: Color(0xFF667EEA),
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FAQScreen(),
                                    ),
                                  ),
                              enabled: true,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Support Categories
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Support Categories',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      Expanded(
                        child: ListView(
                          children: [
                            _buildCategoryItem(
                              Icons.account_circle_outlined,
                              'Account Issues',
                              'Login, password, profile settings',
                              () => _startSupportChat('account'),
                              enabled: SupportApiService.isAuthenticated,
                            ),
                            _buildCategoryItem(
                              Icons.payment_outlined,
                              'Payment & Billing',
                              'Payment issues, refunds, billing',
                              () => _startSupportChat('payment'),
                              enabled: SupportApiService.isAuthenticated,
                            ),
                            _buildCategoryItem(
                              Icons.bug_report_outlined,
                              'Technical Issues',
                              'App bugs, performance issues',
                              () => _startSupportChat('technical'),
                              enabled: SupportApiService.isAuthenticated,
                            ),
                            _buildCategoryItem(
                              Icons.feedback_outlined,
                              'Feedback & Suggestions',
                              'Share your thoughts with us',
                              () => _startSupportChat('feedback'),
                              enabled: SupportApiService.isAuthenticated,
                            ),
                            _buildCategoryItem(
                              Icons.info_outlined,
                              'General Inquiry',
                              'Other questions and support',
                              () => _startSupportChat('general'),
                              enabled: SupportApiService.isAuthenticated,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : () => _showLoginRequiredSnackBar(),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                enabled ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: enabled ? color : Colors.grey),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: enabled ? color : Colors.grey,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? Colors.grey[600] : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            if (!enabled)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LOGIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        enabled: enabled,
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                enabled
                    ? Color(0xFF667EEA).withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: enabled ? Color(0xFF667EEA) : Colors.grey),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!enabled)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LOGIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: enabled ? null : Colors.grey,
            ),
          ],
        ),
        onTap: enabled ? onTap : () => _showLoginRequiredSnackBar(),
      ),
    );
  }

  void _navigateToTickets() {
    if (!SupportApiService.isAuthenticated) {
      _showLoginRequiredSnackBar();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SupportTicketsScreen()),
    );
  }

  void _startSupportChat(String category) async {
    if (!SupportApiService.isAuthenticated) {
      _showLoginRequiredSnackBar();
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating support ticket...'),
                ],
              ),
            ),
      );

      // Create support ticket with category
      final ticket = await SupportApiService.createSupportTicket(category);

      Navigator.pop(context); // Close loading dialog

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  SupportChatScreen(ticket: ticket, category: category),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      // Show error dialog with more details
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Error'),
                ],
              ),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
                if (e.toString().contains('Session expired') ||
                    e.toString().contains('Authentication failed'))
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to login screen
                      // Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF667EEA),
                    ),
                    child: Text('Login'),
                  ),
              ],
            ),
      );
    }
  }

  void _showLoginRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please login to access this feature'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to login screen
            // Navigator.pushNamed(context, '/login');
          },
        ),
      ),
    );
  }
}
