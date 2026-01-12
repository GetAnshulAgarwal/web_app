import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../screen/address_screen.dart';
import '../services/Cart/cart_service.dart';
import '../services/navigation_service.dart';

// 1. Add WidgetsBindingObserver to listen for app resume events
class MainHeader extends StatefulWidget {
  const MainHeader({super.key});

  @override
  State<MainHeader> createState() => _MainHeaderState();
}

class _MainHeaderState extends State<MainHeader> with WidgetsBindingObserver {
  int cartItemCount = 0;
  bool isLoadingCart = false;

  @override
  void initState() {
    super.initState();
    // 2. Register this class as an observer
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCartItemCount();
      // 3. Ensure we check location immediately when the header loads
      _checkLocation();
    });
  }

  @override
  void dispose() {
    // 4. Remove the observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 5. Watch for App Lifecycle changes (Specifically Resumed)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // On iOS, when the permission dialog closes, the app enters the 'resumed' state.
    // We trigger a location check here to catch the new permission status immediately.
    if (state == AppLifecycleState.resumed) {
      print("App resumed - checking location updates...");
      _checkLocation();
    }
  }

  void _checkLocation() {
    // This calls the provider to check if location needs updating (GPS fetch/network)
    // We use listen: false because we are inside a function, not the build method
    context.read<LocationProvider>().checkLocationUpdate();
  }

  Future<void> _loadCartItemCount() async {
    print('=== LOADING CART COUNT ===');

    if (!CartService.isAuthenticated()) {
      print('User not authenticated, setting cart count to 0');
      if (mounted) {
        setState(() {
          cartItemCount = 0;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingCart = true;
      });
    }

    try {
      print('Calling CartService.getCart()...');

      // PERFORMANCE FIX: Apply a timeout to the cart API call
      final cartData = await CartService.getCart().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ Cart API call timed out after 10 seconds.');
          return {'error': 'Timeout'};
        },
      );

      print('Cart data received: $cartData');

      if (cartData != null && cartData['error'] == null) {
        print('Cart data is valid, extracting items...');
        List<dynamic> items = [];
        if (cartData['items'] != null) {
          items = cartData['items'] as List<dynamic>;
        } else if (cartData['data'] != null && cartData['data']['items'] != null) {
          items = cartData['data']['items'] as List<dynamic>;
        } else if (cartData['data'] != null && cartData['data'] is List) {
          items = cartData['data'] as List<dynamic>;
        }
        if (mounted) {
          setState(() {
            cartItemCount = items.length;
          });
        }
        print('Cart count set to: $cartItemCount');
      } else {
        print('Cart data is null or has error: ${cartData?['error']}');
        if (mounted) {
          setState(() {
            cartItemCount = 0;
          });
        }
      }
    } catch (e) {
      print('Error loading cart count: $e');
      if (mounted) {
        setState(() {
          cartItemCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingCart = false;
        });
      }
    }

    print('=== CART COUNT LOADING COMPLETE ===');
  }

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Use Current Location'),
              subtitle: const Text('Get your GPS location'),
              onTap: () {
                context.read<LocationProvider>().refreshLocation();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.book_outlined, color: Colors.green),
              title: const Text('Select from Saved Addresses'),
              subtitle: const Text('Choose a saved address'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddressSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddressSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressScreen(
          isSelectionMode: true,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await context.read<LocationProvider>().checkLocationUpdate();
    }
  }

  void _goToCart() {
    NavigationService.goToCartScreen();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {

        String? statusSubtitle;
        Color locationColor = Colors.black;

        if (locationProvider.location.toLowerCase().contains("denied")) {
          locationColor = Colors.red;
        } else if (!locationProvider.isServiceable) {
          statusSubtitle = "Currently unavailable at this location";
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showLocationOptions,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      locationProvider.isManualAddress
                          ? Icons.location_on
                          : Icons.location_pin,
                      color: Colors.red,
                      size: 28,
                    ),
                    SizedBox(width: screenWidth * 0.015),

                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            locationProvider.location,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: locationColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (statusSubtitle != null)
                            Text(
                              statusSubtitle,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),

                    SizedBox(width: screenWidth * 0.01),

                    if (locationProvider.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(width: screenWidth * 0.02),
                Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final displayCount = cartProvider.totalItemsInCart;
                    final isCartLoading = cartProvider.isLoading;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToCart,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.shopping_bag,
                                size: 26,
                              ),
                              if (displayCount > 0)
                                Positioned(
                                  right: -10,
                                  top: -8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    child: Text(
                                      displayCount > 99 ? '99+' : displayCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              if (isCartLoading)
                                const Positioned(
                                  right: -2,
                                  top: -2,
                                  child: SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}