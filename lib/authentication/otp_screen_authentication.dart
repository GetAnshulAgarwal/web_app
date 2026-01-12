// otp_screen_authentication.dart
import 'package:eshop/authentication/profile_creation_screen.dart';
import 'package:eshop/authentication/user_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../model/Login/user_model.dart';
import '../services/Login/api_service.dart';
import '../services/Notification/firebase_notification_service.dart';
import '../services/warehouse/testing_warehouse_service.dart';
import '../services/warehouse/warehouse_mode_controller.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final DateTime? otpSentTime;
  final VoidCallback? onLoginSuccess;

  const OtpScreen({
    super.key,
    required this.phone,
    this.otpSentTime,
    this.onLoginSuccess,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  DateTime? _otpSentTime;
  final List<TextEditingController> _controllers = List.generate(
    6,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  int _resendAttempts = 0;
  final FirebaseNotificationService _notificationService =
  FirebaseNotificationService();

  @override
  void initState() {
    super.initState();
    _otpSentTime = widget.otpSentTime ?? DateTime.now();
    _startResendTimer();
  }

  void _startResendTimer() {
    final delays = [30, 45, 60, 120, 180, 300];
    final delayIndex = _resendAttempts.clamp(0, delays.length - 1);
    _resendCountdown = delays[delayIndex];

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        if (_resendCountdown <= 0) timer.cancel();
      } else {
        timer.cancel();
      }
    });
  }

  String _formatCountdown() {
    if (_resendCountdown <= 0) return '';
    if (_resendCountdown >= 60) {
      return ' (${_resendCountdown ~/ 60}m ${_resendCountdown % 60}s)';
    } else {
      return ' (${_resendCountdown}s)';
    }
  }

  Future<void> _resendOtp() async {
    FocusScope.of(context).unfocus();

    if (_resendCountdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    for (var controller in _controllers) controller.clear();
    _resendAttempts++;

    try {
      final result = await ApiService.sendOtp(widget.phone);
      if (result['success'] && result['data']['success'] == true) {
        _otpSentTime = DateTime.now();
        _startResendTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP resent successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _focusNodes[0].requestFocus();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['data']['message'] ?? 'Failed to resend OTP'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _fillOtp(String otp) {
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = i < otp.length ? otp[i] : '';
    }
    setState(() {});
    if (otp.length == 6) _focusNodes[5].requestFocus();
  }

  String _getCurrentOtp() => _controllers.map((c) => c.text).join();

  void _onOtpChanged(String value, int index) {
    if (value.isEmpty) {
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return;
    }
    if (value.length > 1) {
      String digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 6) {
        _fillOtp(digits.substring(0, 6));
      } else {
        _controllers[index].text = digits.isNotEmpty ? digits[0] : '';
        if (index < 5 && digits.isNotEmpty) {
          _focusNodes[index + 1].requestFocus();
        }
      }
      return;
    }
    if (value.length == 1 && RegExp(r'\d').hasMatch(value)) {
      if (index < 5) _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _onOtpVerificationSuccess(
      Map<String, dynamic> loginData,
      bool hasToken, {
        String? customerId,
      }) async {
    try {
      final userDataService = UserData();

      if (hasToken) {
        final token = loginData['token'];
        final profileResult = await ApiService.getProfile(token);

        if (profileResult['success']) {
          final userProfile = profileResult['data'];
          final userModel = UserModel(
            phone: userProfile['phone'] ?? widget.phone,
            token: token,
            isLoggedIn: true,
            createdAt: DateTime.now(),
            id: userProfile['_id'] ?? userProfile['id'] ?? customerId,
            name: userProfile['name'],
            email: userProfile['email'],
          );

          await userDataService.saveUser(userModel);
          await _detectAndAssignWarehouse(token);
          await _registerFCMToken(userDataService);

          if (widget.onLoginSuccess != null) widget.onLoginSuccess!();

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/main',
                  (Route<dynamic> route) => false,
            );
          }
        } else {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileCompletionScreen(
                  phone: widget.phone,
                  token: token,
                  customerId: customerId,
                ),
              ),
                  (Route<dynamic> route) => false,
            );
          }
        }
      } else {
        final userModel = UserModel(
          phone: widget.phone,
          isLoggedIn: false,
          createdAt: DateTime.now(),
        );
        await userDataService.saveUser(userModel);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileCompletionScreen(
                phone: widget.phone,
                customerId: customerId,
              ),
            ),
                (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _detectAndAssignWarehouse(String userToken) async {
    try {
      WarehouseModeController.printCurrentMode();
      if (WarehouseModeController.isTestingMode) {
        await TestingWarehouseService.autoAssignTestingWarehouse();
      }
    } catch (e) {
      debugPrint("Error in background warehouse setup: $e");
    }
  }

  Future<void> _registerFCMToken(UserData userDataService) async {
    try {
      await userDataService.registerFCMTokenAfterLogin();
    } catch (e) {
      try {
        await _notificationService.registerDeviceTokenAfterLogin();
      } catch (altError) {
        rethrow;
      }
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    final otp = _getCurrentOtp();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter 6-digit OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await ApiService.verifyOtp(widget.phone, otp);

      if (result.containsKey('data') && result['data'] != null) {
        final data = result['data'];

        if (data['success'] == true) {
          String? token;
          String? customerId;
          Map<String, dynamic> loginData = {};

          if (data['data'] != null) {
            if (data['data']['token'] != null) {
              token = data['data']['token'];
              loginData = data['data'];
            }
            customerId = data['data']['customerId'] ??
                data['data']['_id'] ??
                data['data']['id'];
          }

          if (token == null && data['token'] != null) {
            token = data['token'];
            loginData = {'token': token};
          }

          await _onOtpVerificationSuccess(
            token != null ? loginData : {},
            token != null,
            customerId: customerId,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Invalid OTP'),
                backgroundColor: Colors.red,
              ),
            );
            for (var c in _controllers) c.clear();
            _focusNodes[0].requestFocus();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Network error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8B1A1A)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500), // Center the whole form on web
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: Lottie.asset(
                        'assets/animations/otp.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verify Phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8B1A1A),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter the verification code sent to your phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.phone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- WEB COMPATIBLE OTP BOXES ---
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            final hasValue = _controllers[index].text.isNotEmpty;
                            return SizedBox(
                              width: 50,
                              height: 60,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                onChanged: (value) => _onOtpChanged(value, index),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: hasValue
                                      ? Colors.green.shade700
                                      : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: hasValue,
                                  fillColor: hasValue ? Colors.green.shade50 : Colors.grey.shade50,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: hasValue
                                          ? Colors.green
                                          : const Color(0xFF8B1A1A),
                                      width: hasValue ? 2 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF8B1A1A),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 200,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1A1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Verify',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: (_isResending || _resendCountdown > 0)
                          ? null
                          : _resendOtp,
                      child: Text(
                        _isResending
                            ? 'Resending...'
                            : 'Resend OTP${_formatCountdown()}',
                        style: const TextStyle(
                          color: Color(0xFF8B1A1A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}