// profile_creation_screen.dart
import 'package:flutter/material.dart';
import '../model/Login/user_model.dart';
import '../services/Login/api_service.dart';
import 'user_data.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String phone;
  final String? token;
  final String? customerId;

  const ProfileCompletionScreen({
    Key? key,
    required this.phone,
    this.token,
    this.customerId,
  }) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _referralController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.completeProfile(
      phone: widget.phone,
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
    );

    if (result['success']) {
      final data = result['data'];
      if (data['success'] == true) {
        String? userId = widget.customerId;

        if (data['data'] != null && data['data'] is Map) {
          final d = data['data'];
          userId ??= d['_id'] ?? d['id'] ?? d['customerId'];
        }

        final userModel = UserModel(
          phone: widget.phone,
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          token: data['data']['token'] ?? widget.token,
          isLoggedIn: true,
          createdAt: DateTime.now(),
          id: userId,
        );

        final userData = UserData();
        await userData.saveUser(userModel);
        await userData.registerFCMTokenAfterLogin();

        if (mounted) Navigator.pushReplacementNamed(context, '/main');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to complete profile')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Network error')),
      );
    }
    setState(() => _isLoading = false);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            validator: isRequired
                ? (value) => (value == null || value.trim().isEmpty)
                ? 'This field is required'
                : null
                : null,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              errorStyle: const TextStyle(height: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: isWeb ? Colors.grey[50] : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: isWeb ? 1 : 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF8B1A1A)),
        title: const Text(
          'Complete Profile',
          style: TextStyle(
            color: Color(0xFF8B1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWeb ? 500 : double.infinity),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'One last step!',
                          style: TextStyle(
                            color: Color(0xFF8B1A1A),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Fill in your details to get personalized offers and track your orders.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                        const SizedBox(height: 32),

                        _buildInputField(
                          controller: _nameController,
                          label: 'FULL NAME',
                          isRequired: true,
                          hint: 'Enter your full name',
                        ),
                        const SizedBox(height: 20),

                        _buildInputField(
                          controller: _emailController,
                          label: 'EMAIL ADDRESS',
                          isRequired: false,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'yourname@example.com',
                        ),
                        const SizedBox(height: 20),

                        _buildInputField(
                          controller: _referralController,
                          label: 'REFERRAL CODE (OPTIONAL)',
                          isRequired: false,
                          hint: 'Have a code? Enter it here',
                        ),

                        const SizedBox(height: 40),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _completeProfile,
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
                              'Complete Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}