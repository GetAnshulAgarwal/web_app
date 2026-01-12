import 'package:cached_network_image/cached_network_image.dart';
import 'package:eshop/providers/cart_provider.dart';
import 'package:eshop/providers/notification_provider.dart';
import 'package:eshop/providers/recent_searches_provider.dart';
import 'package:eshop/screen/Address/add_edit_address_screen.dart';
import 'package:eshop/screen/cart_screen.dart';
import 'package:eshop/services/Cart/cart_notifier.dart';
import 'package:eshop/services/Login/api_service.dart' show ApiService;
import 'package:eshop/services/Notification/firebase_notification_service.dart';
import 'package:eshop/services/Updates/firebase_version_manager.dart';
import 'package:eshop/services/home/banner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:lottie/lottie.dart';
import 'package:eshop/authentication/login_screen_authentication.dart';
import 'package:eshop/screen/home_screen.dart';
import 'package:eshop/providers/location_provider.dart';
import 'package:eshop/providers/address_provider.dart';
import 'package:eshop/providers/booking_provider.dart';
import 'package:eshop/services/navigation_service.dart';
import 'package:eshop/authentication/user_data.dart';
import 'buttons/global_cart_button.dart';
import 'firebase_options.dart';
import 'navigation.dart';
import 'dart:async';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Remote Config for version management
  await _initializeRemoteConfig();

  // Initialize Hive
  await UserData.init();

  // Initialize Push Notifications
  await FirebaseNotificationService().initialize();

  CachedNetworkImage.logLevel = CacheManagerLogLevel.warning;

  Timer.periodic(const Duration(hours: 1), (_) {
    BannerApiService.clearOldCache();
  });

  runApp(const MyApp());
}

// Initialize Remote Config
Future<void> _initializeRemoteConfig() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), // Check every hour
      ),
    );

    // Set default values
    await remoteConfig.setDefaults(const {
      'android_latest_version': '4.1.2',
      'android_min_version': '4.1.0',
      'force_update': false,
      'update_title': 'Update Available',
      'update_message': 'A new version is available. Please update to continue using the app.',
      'optional_update_message': 'New features and improvements are available!',
      'android_store_url': 'https://play.google.com/store/apps/details?id=com.anshul.eshop',
      'maintenance_mode': false,
      'maintenance_message': 'The app is currently under maintenance. Please try again later.',
    });

    // Fetch and activate
    await remoteConfig.fetchAndActivate();

    debugPrint('✅ Firebase Remote Config initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Remote Config: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _hasCheckedForUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset the flag when app goes to background, so it checks again on resume
    if (state == AppLifecycleState.paused) {
      _hasCheckedForUpdates = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => CartNotifier()),
        ChangeNotifierProvider(create: (context) => AddressProvider()),
        ChangeNotifierProvider(create: (context) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => RecentSearchesProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<CartNotifier>(
        builder: (context, cartNotifier, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: NavigationService.navigatorKey,
            navigatorObservers: [routeObserver],
            theme: ThemeData(
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                ),
              ),
            ),
            home: UpdateCheckWrapper(
              hasCheckedForUpdates: _hasCheckedForUpdates,
              onUpdateChecked: () {
                _hasCheckedForUpdates = true;
              },
              child: const AuthWrapper(),
            ),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/main': (context) =>
              const MainNavigation(userName: '', phone: '', email: ''),
              '/home': (context) => const HomeScreen(),
              '/cart': (context) => const CartScreen(),
              '/saved_addresses': (context) => const AddEditAddressScreen(),
            },
          );
        },
      ),
    );
  }
}

// Widget to check for updates with proper MaterialApp context
class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;
  final bool hasCheckedForUpdates;
  final VoidCallback onUpdateChecked;

  const UpdateCheckWrapper({
    super.key,
    required this.child,
    required this.hasCheckedForUpdates,
    required this.onUpdateChecked,
  });

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  bool _isCheckingUpdate = true;
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    // Check for updates after the first frame is rendered
    if (!widget.hasCheckedForUpdates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdates();
      });
    } else {
      _isCheckingUpdate = false;
      _canProceed = true;
    }
  }

  Future<void> _checkForUpdates() async {
    // Wait a bit for the context to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      debugPrint('🔍 [UPDATE CHECK] Starting update check...');

      final updateInfo = await FirebaseVersionManager.checkForUpdate();

      debugPrint('🔍 [UPDATE CHECK] Update info received: $updateInfo');
      debugPrint('🔍 [UPDATE CHECK] needsUpdate: ${updateInfo['needsUpdate']}');
      debugPrint('🔍 [UPDATE CHECK] mustUpdate: ${updateInfo['mustUpdate']}');
      debugPrint('🔍 [UPDATE CHECK] maintenanceMode: ${updateInfo['maintenanceMode']}');
      debugPrint('🔍 [UPDATE CHECK] mounted: $mounted');

      if (!mounted) {
        debugPrint('❌ [UPDATE CHECK] Widget not mounted, aborting');
        return;
      }

      widget.onUpdateChecked(); // Mark as checked

      // Check maintenance mode first
      if (updateInfo['maintenanceMode'] == true) {
        debugPrint('⚠️ [UPDATE CHECK] Showing maintenance dialog');
        await FirebaseVersionManager.showMaintenanceDialog(
          context,
          updateInfo['message'] ?? 'App is under maintenance',
        );
        // Don't proceed if in maintenance mode
        setState(() {
          _isCheckingUpdate = false;
          _canProceed = false;
        });
        return;
      }

      // Check for updates
      if (updateInfo['needsUpdate'] == true) {
        debugPrint(' [UPDATE CHECK] Showing update dialog');

        // If it's a forced update, don't allow proceeding
        if (updateInfo['mustUpdate'] == true) {
          await FirebaseVersionManager.showUpdateDialog(context, updateInfo);
          debugPrint(' [UPDATE CHECK] Forced update required - blocking navigation');
          setState(() {
            _isCheckingUpdate = false;
            _canProceed = false;
          });
        } else {
          // Optional update - show dialog but allow proceeding
          FirebaseVersionManager.showUpdateDialog(context, updateInfo);
          debugPrint('✅ [UPDATE CHECK] Optional update - allowing navigation');
          setState(() {
            _isCheckingUpdate = false;
            _canProceed = true;
          });
        }
      } else {
        debugPrint('ℹ️ [UPDATE CHECK] No update needed');
        setState(() {
          _isCheckingUpdate = false;
          _canProceed = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [UPDATE CHECK] Error: $e');
      debugPrint('❌ [UPDATE CHECK] Stack trace: $stackTrace');
      // On error, allow proceeding
      setState(() {
        _isCheckingUpdate = false;
        _canProceed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking for updates
    if (_isCheckingUpdate) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If forced update is required, show a blocking screen
    if (!_canProceed) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.update, size: 80, color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Update Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Please update the app to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Allow normal flow
    return widget.child;
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  int _currentFactIndex = 0;
  Timer? _factTimer;
  bool _isLoading = true;

  final List<String> _interestingFacts = [
    "🛒 Online shopping saves an average of 2.5 hours per week!",
    "📱 Mobile commerce accounts for over 50% of e-commerce sales",
    "🌍 E-commerce grows by 15% globally every year",
    "💡 The first online purchase was made in 1994 - a CD!",
    "🚀 Amazon started as an online bookstore in 1994",
    "🛍️ 87% of shoppers begin product searches online",
    "💳 Digital wallets are used by over 2.8 billion people worldwide",
    "📦 Same-day delivery is now available in over 100 cities",
    "🎯 AI helps recommend products with 35% better accuracy",
  ];

  @override
  void initState() {
    super.initState();
    _startFactRotation();
    _initializeApp();
  }

  void _startFactRotation() {
    _factTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          _currentFactIndex =
              (_currentFactIndex + 1) % _interestingFacts.length;
        });
      }
    });
  }

  void _initializeApp() async {
    try {
      final result = await _determineInitialScreen();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => result),
        );
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/Loading.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Text(
                    "Did You Know?",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      _interestingFacts[_currentFactIndex],
                      key: ValueKey(_currentFactIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Widget> _determineInitialScreen() async {
    await Future.delayed(const Duration(milliseconds: 5000));
    return await _performAuthentication();
  }

  Future<Widget> _performAuthentication() async {
    final userData = UserData();

    if (userData.isLoggedIn()) {
      final user = userData.getCurrentUser();

      if (user != null &&
          user.token != null &&
          (user.name == null || user.name!.isEmpty)) {
        await _fetchAndUpdateProfile(user.token!);
      }

      await userData.registerFCMTokenAfterLogin();

      final updatedUser = userData.getCurrentUser();
      return MainNavigation(
        userName: updatedUser?.name ?? 'Guest User',
        phone: updatedUser?.phone ?? '',
        email: updatedUser?.email ?? '',
      );
    } else {
      return const LoginScreen();
    }
  }

  Future<void> _fetchAndUpdateProfile(String token) async {
    try {
      final profileResult = await ApiService.getProfile(token);

      if (profileResult['success']) {
        final profileData = profileResult['data'];
        if (profileData['success'] == true && profileData['data'] != null) {
          final profile = profileData['data'];

          final userData = UserData();
          await userData.updateUser(
            name: profile['name'],
            email: profile['email'],
            city: profile['city'],
            state: profile['state'],
            country: profile['country'],
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }
}