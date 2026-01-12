// login_screen_authentication.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';
import '../services/Notification/firebase_notification_service.dart';
import 'otp_screen_authentication.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  final FirebaseNotificationService _notificationService =
  FirebaseNotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize(
        onNotificationTap: (route) {
          _handleNotificationNavigation(route);
        },
      );
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  void _handleNotificationNavigation(String route) {
    if (route.startsWith('/order-details/')) {
      final orderId = route.split('/').last;
      Navigator.pushNamed(context, '/order-details', arguments: orderId);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    final fullPhoneNumber = '+91$phone';
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://pos.inspiredgrow.in/vps/customer/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': fullPhoneNumber}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              phone: fullPhoneNumber,
              otpSentTime: DateTime.now(),
              onLoginSuccess: _handleLoginSuccess,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLoginSuccess() async {
    try {
      await _notificationService.registerDeviceTokenAfterLogin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful! You\'ll receive order notifications.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error registering for notifications: $e');
    }
  }

  void _skipToHome() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isWeb = size.width > 800;

    return Scaffold(
      backgroundColor: isWeb ? Colors.grey[50] : Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // Skip Now Button
              Positioned(
                top: 20,
                right: 20,
                child: TextButton.icon(
                  onPressed: _skipToHome,
                  icon: const Text('Skip Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  label: const Icon(Icons.arrow_forward_ios, size: 14),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B1A1A)),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWeb ? 450 : double.infinity),
                      child: Container(
                        padding: EdgeInsets.all(isWeb ? 40 : 0),
                        decoration: isWeb ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ) : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Branding/Animation Section
                            Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: isWeb ? 220 : 250,
                                    width: isWeb ? 220 : 250,
                                    child: Lottie.asset(
                                      'assets/animations/groceries.json',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Welcome Back!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Text(
                              'Login',
                              style: TextStyle(
                                color: Color(0xFF8B1A1A),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Input Section
                            const Text(
                              'PHONE NUMBER',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Text(
                                      '+91',
                                      style: TextStyle(
                                        color: Color(0xFF8B1A1A),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(height: 24, width: 1, color: Colors.grey[300]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      style: const TextStyle(fontSize: 18, letterSpacing: 1.5),
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        hintText: '00000 00000',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B1A1A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'Send Verification Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Center(
                              child: Text(
                                'By logging in, you agree to our Terms & Conditions',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}