import 'package:flutter/material.dart';

import '../../model/Support/faq_item.dart';
import '../ProfileSubScreen/help_and_support_screen.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  _FAQScreenState createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  TextEditingController searchController = TextEditingController();
  List<FAQItem> allFAQs = [];
  List<FAQItem> filteredFAQs = [];

  @override
  void initState() {
    super.initState();
    _loadFAQs();
  }

  void _loadFAQs() {
    // Sample FAQ data - replace with actual API call
    allFAQs = [
      FAQItem(
        id: 1,
        question: 'How do I reset my password?',
        answer:
            'You can reset your password by going to the login screen and tapping "Forgot Password". Follow the instructions sent to your email.',
        category: 'Account',
      ),
      FAQItem(
        id: 2,
        question: 'How do I contact customer support?',
        answer:
            'You can contact our support team through the Help & Support section in the app, or by creating a new support ticket.',
        category: 'Support',
      ),
      FAQItem(
        id: 3,
        question: 'How do I update my profile information?',
        answer:
            'Go to Settings > Profile to update your personal information, including name, email, and phone number.',
        category: 'Account',
      ),
      FAQItem(
        id: 4,
        question: 'Why is my payment failing?',
        answer:
            'Payment failures can occur due to insufficient funds, expired cards, or network issues. Please check your payment method and try again.',
        category: 'Payment',
      ),
      FAQItem(
        id: 5,
        question: 'How do I cancel my subscription?',
        answer:
            'You can cancel your subscription by going to Settings > Subscription and selecting "Cancel Subscription".',
        category: 'Billing',
      ),
      FAQItem(
        id: 6,
        question: 'Is my data secure?',
        answer:
            'Yes, we use industry-standard encryption and security measures to protect your personal information and data.',
        category: 'Security',
      ),
    ];

    setState(() {
      filteredFAQs = allFAQs;
    });
  }

  void _filterFAQs(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredFAQs = allFAQs;
      } else {
        filteredFAQs =
            allFAQs
                .where(
                  (faq) =>
                      faq.question.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      faq.answer.toLowerCase().contains(query.toLowerCase()) ||
                      faq.category.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Frequently Asked Questions'),
        backgroundColor: Color(0xFF667EEA),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF667EEA).withOpacity(0.1),
            child: TextField(
              controller: searchController,
              onChanged: _filterFAQs,
              decoration: InputDecoration(
                hintText: 'Search FAQs...',
                prefixIcon: Icon(Icons.search),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            _filterFAQs('');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // FAQ List
          Expanded(
            child:
                filteredFAQs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: filteredFAQs.length,
                      itemBuilder: (context, index) {
                        final faq = filteredFAQs[index];
                        return _buildFAQCard(faq);
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HelpSupportMainScreen()),
            ),
        icon: Icon(Icons.chat),
        label: Text('Contact Support'),
        backgroundColor: Color(0xFF48BB78),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No FAQs Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCard(FAQItem faq) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Container(
          margin: EdgeInsets.only(top: 4),
          child: Text(
            faq.category,
            style: TextStyle(
              color: Color(0xFF667EEA),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(),
                SizedBox(height: 8),
                Text(
                  faq.answer,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Glad this was helpful!')),
                        );
                      },
                      icon: Icon(Icons.thumb_up_outlined, size: 16),
                      label: Text('Helpful'),
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFF48BB78),
                      ),
                    ),
                    SizedBox(width: 8),
                    TextButton.icon(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HelpSupportMainScreen(),
                            ),
                          ),
                      icon: Icon(Icons.chat_outlined, size: 16),
                      label: Text('Need More Help'),
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFF667EEA),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
