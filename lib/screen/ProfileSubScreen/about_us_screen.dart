import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  // Clipboard utility
  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // URL launcher (updated: no canLaunchUrl check)
  Future<void> launchURL(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open the link.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Copy Link',
              textColor: Colors.white,
              onPressed: () => copyToClipboard(context, url),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Expansion tile widget generator
  Widget buildExpansionTile({
    required BuildContext context,
    required String title,
    required String content,
    String? buttonLabel,
    String? url,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          initiallyExpanded: title == 'About Us',
          children: [
            Text(
              content,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (url != null && buttonLabel != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => launchURL(context, url),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.open_in_new,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'About Us',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            buildExpansionTile(
              context: context,
              title: 'About Us',
              content:
                  'The Grocery On Wheels app is a smart, intuitive platform designed to enhance last-mile grocery delivery through our mobile van network. Customers can easily track nearby vans in real time, browse the product catalogue, check availability, and place orders instantly. Our app empowers users in low and mid-density areas with the convenience of doorstep access to fresh groceries and daily essentials. With features like live van alerts, secure digital payments, and multilingual support, the app brings together technology and mobility to solve accessibility gaps in underserved regions - delivering reliability, convenience, and trust with every transaction.',
            ),
            buildExpansionTile(
              context: context,
              title: 'Terms & Conditions',
              content:
                  'By using our services, you agree to comply with our terms and conditions. These terms govern your use of our platform and services.',
              buttonLabel: 'View Full Terms & Conditions',
              url: 'https://inspiredgrow.in/terms-of-use/',
            ),
            buildExpansionTile(
              context: context,
              title: 'Privacy Policy',
              content:
                  'We value your privacy and are committed to protecting your personal information. Our privacy policy outlines how we collect, use, and safeguard your data.',
              buttonLabel: 'View Full Privacy Policy',
              url: 'https://inspiredgrow.in/privacy-policy/',
            ),
          ], 
        ),
      ),
    );
  }
}
