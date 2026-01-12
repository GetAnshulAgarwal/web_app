import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';

class FirebaseVersionManager {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Get current build number
  static Future<String> getBuildNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.buildNumber;
  }

  /// Check if app is in maintenance mode
  static bool isMaintenanceMode() {
    return _remoteConfig.getBool('maintenance_mode');
  }

  /// Get maintenance message
  static String getMaintenanceMessage() {
    return _remoteConfig.getString('maintenance_message');
  }

  /// Check for updates
  static Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      // Fetch latest config from Firebase
      await _remoteConfig.fetchAndActivate();

      final currentVersion = await getCurrentVersion();

      // Get values from Remote Config
      final latestVersion = _remoteConfig.getString('android_latest_version');
      final minVersion = _remoteConfig.getString('android_min_version');
      final forceUpdate = _remoteConfig.getBool('force_update');
      final storeUrl = _remoteConfig.getString('android_store_url');
      final updateTitle = _remoteConfig.getString('update_title');
      final updateMessage = _remoteConfig.getString('update_message');
      final optionalUpdateMessage = _remoteConfig.getString('optional_update_message');

      debugPrint('📱 Current Version: $currentVersion');
      debugPrint('🔄 Latest Version: $latestVersion');
      debugPrint('⚠️ Min Required Version: $minVersion');
      debugPrint('🔒 Force Update: $forceUpdate');

      // Check if maintenance mode
      if (isMaintenanceMode()) {
        return {
          'maintenanceMode': true,
          'message': getMaintenanceMessage(),
        };
      }

      // Compare versions
      final needsUpdate = _compareVersions(currentVersion, latestVersion) < 0;
      final mustUpdate = _compareVersions(currentVersion, minVersion) < 0 || forceUpdate;

      return {
        'needsUpdate': needsUpdate,
        'mustUpdate': mustUpdate,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'minVersion': minVersion,
        'updateTitle': updateTitle,
        'updateMessage': mustUpdate ? updateMessage : optionalUpdateMessage,
        'storeUrl': storeUrl,
        'maintenanceMode': false,
      };
    } catch (e) {
      debugPrint('❌ Error checking update: $e');
      return {'needsUpdate': false, 'mustUpdate': false};
    }
  }

  /// Compare version strings (e.g., "1.0.0" vs "1.0.1")
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  static int _compareVersions(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map(int.parse).toList();
      final parts2 = v2.split('.').map(int.parse).toList();

      // Ensure both have same length
      while (parts1.length < parts2.length) parts1.add(0);
      while (parts2.length < parts1.length) parts2.add(0);

      for (int i = 0; i < parts1.length; i++) {
        if (parts1[i] < parts2[i]) return -1;
        if (parts1[i] > parts2[i]) return 1;
      }
      return 0;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return 0;
    }
  }

  /// Open Play Store
  static Future<void> openPlayStore(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('❌ Cannot launch Play Store URL');
      }
    } catch (e) {
      debugPrint('❌ Error opening Play Store: $e');
    }
  }

  /// Show update screen with Lottie animation - FULL SCREEN UI
  static Future<void> showUpdateDialog(
      BuildContext context,
      Map<String, dynamic> updateInfo,
      ) async {
    final mustUpdate = updateInfo['mustUpdate'] ?? false;

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PopScope(
          canPop: !mustUpdate,
          child: _UpdateScreen(updateInfo: updateInfo),
        ),
        opaque: true,
        barrierDismissible: !mustUpdate,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  static Widget _buildModernVersionRow(
      String label,
      String version,
      IconData icon,
      Color color,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                version,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Show maintenance dialog - MODERN UI
  static Future<void> showMaintenanceDialog(BuildContext context, String message) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon with gradient background
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.orange.shade400, Colors.orange.shade700],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.construction,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Under Maintenance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We\'ll be back shortly. Thank you for your patience!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Close App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full Screen Update Page with Lottie Animation
class _UpdateScreen extends StatelessWidget {
  final Map<String, dynamic> updateInfo;

  const _UpdateScreen({required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    final mustUpdate = updateInfo['mustUpdate'] ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
            child: Column(
              children: [
                // Close button (only for optional updates)
                if (!mustUpdate)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Lottie Animation
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Lottie.asset(
                    'assets/animations/Update.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    animate: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: mustUpdate
                                ? [Colors.red.shade400, Colors.red.shade700]
                                : [Colors.blue.shade400, Colors.blue.shade700],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          mustUpdate ? Icons.system_update_alt : Icons.auto_awesome,
                          color: Colors.white,
                          size: 80,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  updateInfo['updateTitle'] ?? 'Update Available',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Message
                Text(
                  updateInfo['updateMessage'] ?? 'Please update to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Version Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey.shade50,
                        Colors.grey.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      FirebaseVersionManager._buildModernVersionRow(
                        'Current Version',
                        updateInfo['currentVersion'],
                        Icons.phone_android,
                        Colors.grey.shade700,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade200,
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FirebaseVersionManager._buildModernVersionRow(
                        'Latest Version',
                        updateInfo['latestVersion'],
                        Icons.new_releases,
                        Colors.green.shade600,
                      ),
                    ],
                  ),
                ),

                // Warning Badge for forced updates
                if (mustUpdate) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.priority_high,
                            color: Colors.red.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'This update is required to continue using the app',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Action Buttons
                Column(
                  children: [
                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          final url = updateInfo['storeUrl'];
                          await FirebaseVersionManager.openPlayStore(url);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mustUpdate ? Colors.red.shade600 : Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: (mustUpdate ? Colors.red : Colors.blue).withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Update Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Later Button (only for optional updates)
                    if (!mustUpdate) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            ),
                          ),
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}