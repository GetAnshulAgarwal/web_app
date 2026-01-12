import 'package:eshop/screen/ProfileSubScreen/Wallet/wallet_Screen.dart';
import 'package:eshop/screen/ProfileSubScreen/help_and_support_screen.dart';
import 'package:eshop/screen/SubScreen/Comming_Soon_Screen.dart';
import 'package:eshop/screen/Support/chat_support.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../authentication/user_data.dart';
import '../services/navigation_service.dart';
import 'ProfileSubScreen/about_us_screen.dart';
// import 'ProfileSubScreen/account_deletion_screen.dart'; // REMOVE THIS IMPORT if not used elsewhere in this file
import 'ProfileSubScreen/account_privacy_screen.dart'; // ADD THIS IMPORT
import 'ProfileSubScreen/my_van_bookings_screen.dart';
import 'ProfileSubScreen/rate_us_screen.dart';
import 'ProfileSubScreen/refer_sub_screen.dart';
import 'ProfileSubScreen/referal_screen.dart';
import 'ProfileSubScreen/your_order_screen.dart';

import 'SubScreen/setting_profile_screen.dart';
import 'address_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String userName = 'Guest User';
  String phone = '';
  String email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final userData = UserData();
    final loadedName = await userData.getName();
    final loadedPhone = await userData.getPhone();
    final loadedEmail = await userData.getEmail();
    setState(() {
      userName = (loadedName.isNotEmpty) ? loadedName : 'Guest User';
      phone = (loadedPhone != null && loadedPhone.isNotEmpty) ? loadedPhone : '';
      email = (loadedEmail != null && loadedEmail.isNotEmpty) ? loadedEmail : '';
      _isLoading = false;
    });
  }

  Future<void> _onRefresh() async {
    await _loadUserData();
  }

  void _shareApp(BuildContext context) {
    const String appLink =
        'https://play.google.com/store/apps/details?id=com.inspiredgrow.customerapp';
    const String shareMessage =
        'Check out Grocery on Wheels, a convenient way to get groceries delivered! Download now: $appLink';
    Share.share(shareMessage);
  }

  Future<void> _logOut() async {
    final userData = UserData();
    await userData.clearUserData();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _navigateToProfileAndHandleResult() async {
    final Map<String, String>? updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ProfileScreen(
          initialName: userName,
          initialEmail: email,
          initialPhone: phone,
        ),
      ),
    );
    if (updatedData != null) {
      await UserData().updateUser(
        name: updatedData['name'],
        email: updatedData['email'],
      );
      if (mounted) {
        setState(() {
          userName =
          (updatedData['name'] != null && updatedData['name']!.isNotEmpty)
              ? updatedData['name']!
              : userName;
          email =
          (updatedData['email'] != null && updatedData['email']!.isNotEmpty)
              ? updatedData['email']!
              : email;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return PopScope(
      canPop: isIOS,
      onPopInvoked: (didPop) {
        if (didPop) return;
        NavigationService.goBackToHomeScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              NavigationService.goBackToHomeScreen();
            },
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _onRefresh),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Section ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (phone.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14),
                                  const SizedBox(width: 4),
                                  Text(phone),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (email.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 14),
                                  const SizedBox(width: 4),
                                  Text(email),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            GestureDetector(
                              onTap: _navigateToProfileAndHandleResult,
                              child: const Text(
                                "See More >",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.black12,
                        child: Icon(Icons.person, size: 30),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- Information Grid Section ---
                const Text(
                  "Information",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: (screenWidth / 3) / 100,
                    children: [
                      _InfoTile(
                        icon: Icons.book_online_outlined,
                        label: "Your booking",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MyVanBookingsScreen()),
                        ),
                      ),
                      _InfoTile(
                        icon: Icons.support_agent_outlined,
                        label: "Help & support",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ChatSupportPage()),
                        ),
                      ),
                      _InfoTile(
                        icon: Icons.card_giftcard,
                        label: "Refer",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ReferEarnScreen()),
                        ),
                      ),
                      _InfoTile(
                        icon: Icons.location_on_outlined,
                        label: "Saved Address",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AddressScreen()),
                        ),
                      ),
                      _InfoTile(
                        icon: Icons.wallet,
                        label: "Wallet",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const WalletScreen()),
                        ),
                      ),
                      _InfoTile(
                        icon: Icons.shopping_cart,
                        label: "Your Order",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OrdersScreen()),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Other Information",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _OtherItem(
                        icon: Icons.share,
                        label: "Share the app",
                        onTap: () => _shareApp(context),
                      ),
                      _OtherItem(
                        icon: Icons.info_outline,
                        label: "About us",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AboutUsScreen()),
                        ),
                      ),
                      _OtherItem(
                        icon: Icons.star_border,
                        label: "Rate us",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RateUsScreen()),
                        ),
                      ),
                      _OtherItem(
                        icon: Icons.notifications,
                        label: "Notification",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ComingSoonScreen()),
                        ),
                      ),

                      // ============================================
                      // UPDATED: Account Privacy Button
                      // ============================================
                      _OtherItem(
                        icon: Icons.privacy_tip_outlined, // Changed Icon
                        label: "Account Privacy",        // Changed Label
                        iconColor: Colors.black,         // Changed Color (Standard black)
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Navigates to the new intermediate screen first
                            builder: (context) => const AccountPrivacyScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- Logout Button ---
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Logout"),
                            content: const Text(
                              "Are you sure you want to logout?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _logOut();
                                },
                                child: const Text("Logout"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text(
                      "Logout",
                      style: TextStyle(fontWeight: FontWeight.bold),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            child: Icon(icon, color: Colors.black, size: 25),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _OtherItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _OtherItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: iconColor),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: iconColor,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }
}