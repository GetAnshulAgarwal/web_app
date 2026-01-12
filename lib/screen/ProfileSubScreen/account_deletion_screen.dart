import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../services/Login/api_service.dart';
import '../../authentication/user_data.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  final List<String> _deletionReasons = [
    'Not using the app anymore',
    'Found a better alternative',
    'Privacy concerns',
    'Too many notifications',
    'App is too slow',
    'Other',
  ];

  String _selectedReason = 'Not using the app anymore';
  bool _showCustomReason = false;

  Future<void> _submitDeletionRequest() async {
    if (_selectedReason == 'Other' && _reasonController.text.trim().isEmpty) {
      _showSnackBar('Please provide a reason for deletion', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final reason = _selectedReason == 'Other'
        ? _reasonController.text.trim()
        : _selectedReason;

    // Call the updated API
    final result = await ApiService.requestAccountDeletion(reason: reason);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success']) {
        // Navigate to the new Success Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AccountDeletionSuccessScreen(),
          ),
        );
      } else {
        _showSnackBar(result['error'] ?? 'Failed to submit request', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone immediately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitDeletionRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B1A1A)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Note: Deleting your account is permanent. All your data including orders, wallet balance, and saved addresses will be removed.',
                      style: TextStyle(color: Colors.red[900], fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reasons Section
            const Text(
              'Why do you want to leave?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: _deletionReasons.map((reason) {
                  return RadioListTile<String>(
                    value: reason,
                    groupValue: _selectedReason,
                    activeColor: const Color(0xFF8B1A1A),
                    onChanged: (value) {
                      setState(() {
                        _selectedReason = value!;
                        _showCustomReason = value == 'Other';
                      });
                    },
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    dense: true,
                  );
                }).toList(),
              ),
            ),

            // Custom Reason Input
            if (_showCustomReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Please share your reason...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B1A1A)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Confirm Deletion',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// NEW SUCCESS SCREEN UI
// ==========================================

class AccountDeletionSuccessScreen extends StatefulWidget {
  const AccountDeletionSuccessScreen({super.key});

  @override
  State<AccountDeletionSuccessScreen> createState() => _AccountDeletionSuccessScreenState();
}

class _AccountDeletionSuccessScreenState extends State<AccountDeletionSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    // Perform local logout while user sees the success screen
    _performLocalLogout();
  }

  Future<void> _performLocalLogout() async {
    final userData = UserData();
    await userData.clearUserData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prevent back button
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Lottie Animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    // Use a checkmark or success lottie here
                    child: Lottie.asset(
                      'assets/animations/success.json', // Ensure you have this or use 'request.json'
                      fit: BoxFit.contain,
                      repeat: false,
                      errorBuilder: (context, error, stack) {
                        return const Icon(Icons.check_circle_outline, size: 100, color: Colors.green);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                const Text(
                  'Request Submitted',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // The specific message you requested
                const Text(
                  'Your account deletion request has been received successfully.\n\nIt will take 24 hours from our end to complete your request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),

                const Spacer(),

                // Done Button (Navigates to Login/Home)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to Login screen and remove all previous routes
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                              (Route<dynamic> route) => false
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}