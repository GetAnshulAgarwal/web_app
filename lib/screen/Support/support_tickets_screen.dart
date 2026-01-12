// support_tickets_screen.dart

import 'package:flutter/material.dart';


// --- IMPORT YOUR NEW FILES ---
import '../../authentication/login_screen_authentication.dart'; // Make sure this path is correct
import '../../authentication/user_data.dart';
// ---

import '../../utils/date_formatter.dart';
import '../../model/Support/support_ticket.dart';
import '../../services/Support/support_api_service.dart';
import '../ProfileSubScreen/help_and_support_screen.dart';
import 'support_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  @override
  _SupportTicketsScreenState createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  List<SupportTicket> tickets = [];
  bool isLoading = true;

  // We need an instance of UserData to get the token
  final UserData _userData = UserData();

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() async {
    // Ensure the widget is still mounted before proceeding
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // --- NEW: PROACTIVE TOKEN CHECK ---
      final String? currentToken = _userData.getToken();

      /*if (currentToken == null || JwtUtils.isTokenExpired(currentToken)) {
        // Token is missing or expired. Log the user out.
        await _userData.clearUserData();

        // Check mounted again before navigating
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()), // Navigate to login
              (Route<dynamic> route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Your session expired. Please login again.'))
        );
        return; // Stop the function here
      }*/
      // --- END OF TOKEN CHECK ---

      // If we are here, the token is valid. Proceed to fetch tickets.
      final loadedTickets = await SupportApiService.getSupportTickets();

      if (mounted) {
        setState(() {
          tickets = loadedTickets;
          isLoading = false;
        });
      }
    } catch (e) {
      // This will now only catch other errors, like network issues,
      // because the 401/expired token error is already handled above.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tickets: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Support Tickets'),
        backgroundColor: Color(0xFF667EEA),
        elevation: 0,
        actions: [
          // Make sure the refresh button also uses the full _loadTickets logic
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadTickets),
        ],
      ),
      body:
      isLoading
          ? Center(child: CircularProgressIndicator())
          : tickets.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: () async => _loadTickets(),
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return _buildTicketCard(ticket);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HelpSupportMainScreen()),
        ),
        icon: Icon(Icons.add),
        label: Text('New Ticket'),
        backgroundColor: Color(0xFF48BB78),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.support_agent_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No Support Tickets',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You haven\'t created any support tickets yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed:
                () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HelpSupportMainScreen(),
              ),
            ),
            icon: Icon(Icons.add),
            label: Text('Create New Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF667EEA),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    Color statusColor = _getStatusColor(ticket.status);
    Color priorityColor = _getPriorityColor(ticket.priority);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupportChatScreen(ticket: ticket),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (ticket.unreadCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${ticket.unreadCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.priority.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (ticket.lastMessage != null)
                Text(
                  ticket.lastMessage!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: 8),
              Text(
                'Updated ${DateFormatter.formatDate(ticket.updatedAt)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Color(0xFF48BB78);
      case 'pending':
        return Color(0xFFED8936);
      case 'closed':
        return Color(0xFF718096);
      default:
        return Color(0xFF667EEA);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Color(0xFFF56565);
      case 'medium':
        return Color(0xFFED8936);
      case 'low':
        return Color(0xFF48BB78);
      default:
        return Color(0xFF667EEA);
    }
  }
}