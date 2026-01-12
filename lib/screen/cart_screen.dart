import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/cart_provider.dart';
import '../../authentication/user_data.dart';
import '../../services/navigation_service.dart';
import '../model/cart/cart_item_model.dart';
import '../model/home/product_model.dart';
import '../model/Address/address_model.dart';
import '../services/Address/address_service.dart';
import '../services/Cart/cart_service.dart';
import '../services/Order/order_api_service.dart';
import '../services/home/api_service.dart';
import '../services/stock_service.dart';
import '../services/Wallet/wallet_api_services.dart';
import '../widget/Cart/address_form_widget.dart';
import '../widget/Cart/billing_details_widget.dart';
import '../widget/Cart/cart_options_widgets.dart';
import '../widget/Cart/coupon_widgets.dart';
import '../widget/Cart/order_summary_widget.dart';
import '../widget/Cart/price_summary_widget.dart';
import '../widget/Cart/popular_products_widget.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> cartItems = [];
  List<Product> popularProducts = [];

  double totalAmount = 0.0; // This will act as the subtotal
  double totalItems = 0.0;
  bool _hasShownSwipeHint = false;
  bool _isShowingHint = false;
  bool isLoading = true;
  String? errorMessage;
  bool isAuthenticated = false;
  int walletPoints = 0;
  bool isWalletLoading = false;

  // --- REFACTORED PRICE STATE ---
  double deliveryFee = 0.0;
  double handlingFee = 0.0;
  String deliveryFeeName = 'Delivery Charge';
  String handlingFeeName = 'Processing Fee';
  double thresholdAmount = 0.0;
  String thresholdMessage = '';
  bool isFreeDelivery = false;
  final double platformFee = 0.0;
  final double cartFee = 0.0;
  // --- END OF REFACTORED PRICE STATE ---

  // Dynamic components
  double selectedTip = 0.0;
  double selectedDonation = 0.0;
  bool isInstantDelivery = false;
  bool isLoadingPopularProducts = true;
  String selectedTipAmount = '';
  String selectedDonationAmount = '';

  // NEW: Delivery slots related variables
  static Map<String, List<Map<String, dynamic>>>? _memoryCachedSlots;
  static List<Map<String, dynamic>>? _memoryCachedAvailableSlots;
  static DateTime? _lastSlotsFetchTime;

  List<Map<String, dynamic>> availableSlots = [];
  Map<String, List<Map<String, dynamic>>> slotsByDate = {};
  bool isLoadingSlots = false;
  String? selectedSlotId;
  Map<String, dynamic>? selectedSlotData;
  bool showSlotSelection = true;
  // --- NEW UI STATE ---
  String? _selectedDateKey; // Tracks the selected date chip (e.g., "Today")
  Timer? _slotsRefreshTimer;
  bool _isAutoRefreshEnabled = true;
  // --- END NEW UI STATE ---

  // Checkout form controllers
  final _formKey = GlobalKey<FormState>();
  final _houseNoController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isCheckoutLoading = false;
  bool _isPreparingCheckout = false;
  bool _showAddressForm = false;

  List<Address> savedAddresses = [];
  Address? selectedAddress;
  bool isLoadingAddresses = false;

  // Coupon Section
  CouponModel? selectedCoupon;
  double couponDiscountAmount = 0.0;

  // Order tracking
  late String? _lastOrderId;
  String? _lastOrderNumber;
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;
  List<String> _outOfStockItemIds = [];
  int get totalItemsCount => totalItems.toInt();
  double? _lastDiscountAmount;
  bool _isRedeemed = false;

  // Inside _CartScreenState
  @override
  void initState() {
    super.initState();
    isAuthenticated = CartService.isAuthenticated();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet); // REQUIRED for stability

    if (isAuthenticated) {
      Future.wait([
        loadDeliverySlots(),
        fetchWalletBalance(),
        loadPopularProducts(),
      ]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithProvider();
    });
  }
  void _handleExternalWallet(ExternalWalletResponse response) {
    // Just log it or show a simple message.
    // On Web, this is rarely triggered but the listener must exist.
    print("External Wallet selected: ${response.walletName}");
  }

  void _syncWithProvider() {
    final bool authStatus = CartService.isAuthenticated();
    setState(() {
      isAuthenticated = authStatus;
    });
    if (!authStatus) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.cartItems.isNotEmpty) {
      setState(() {
        isLoading = false;
      });
      loadCart();
    } else {
      loadCart();
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _houseNoController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _locationController.dispose();
    _slotsRefreshTimer?.cancel();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessingPayment = false;
    });
    _handleRazorpayPaymentSuccess(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;

    print("Payment Error: ${response.code} - ${response.message}");

    setState(() {
      _isProcessingPayment = false;
    });

    // On Web, closing the popup without paying triggers a specific error code (0 or 2)
    // We can show a gentler message for cancellations.
    String msg = response.message ?? 'Payment failed';
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      msg = "Payment cancelled by user";
    }

    _showFailureDialog('Payment Failed', message: msg);
  }
  /*void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }*/

  /*void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() {
      _isProcessingPayment = false;
    });
    _showErrorMessage('External wallet selected: ${response.walletName}');
  }*/

  void _openRazorpayCheckout() {
    if (_isProcessingPayment) {
      _showErrorMessage('Payment already in progress');
      return;
    }

    final userData = UserData();
    final user = userData.getCurrentUser();

    // Ensure amount is valid
    double finalRupeeAmount = grandTotal - (_lastDiscountAmount ?? 0);
    if (finalRupeeAmount < 1) {
      _showErrorMessage('Amount must be at least ₹1');
      return;
    }

    // Prepare Options
    var options = {
      'key': 'rzp_live_RN5l7ppvEWmNxm', // Ensure this is your correct LIVE key
      'amount': (finalRupeeAmount * 100).toInt(), // Amount in paise
      'name': 'Grocery On Wheels',
      'description': 'Order #${DateTime.now().millisecondsSinceEpoch}', // Unique desc helps tracking
      'retry': {'enabled': true, 'max_count': 1}, // Helps if network fluctuates
      'send_sms_hash': true,
      'prefill': {
        'contact': user?.phone ?? '',
        'email': user?.email ?? '',
      },
      'theme': {
        'color': '#5D4037',
      },
    };

    try {
      setState(() {
        _isProcessingPayment = true;
      });
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
      });
      print("Razorpay Error: $e");
      _showErrorMessage('Error opening payment gateway. Please retry.');
    }
  }

  void checkAuthAndLoadCart() {
    final bool authStatus = CartService.isAuthenticated();
    if (authStatus) {
      setState(() {
        isAuthenticated = true;
        isLoading = true;
        errorMessage = null;
      });
      loadCart();
    } else {
      setState(() {
        isAuthenticated = false;
        isLoading = false;
        errorMessage = null;
      });
    }
  }

  void _showSwipeHintForFirstItem() async {
    if (_hasShownSwipeHint || cartItems.isEmpty) return;

    setState(() {
      _hasShownSwipeHint = true;
      _isShowingHint = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isShowingHint = false;
      });
    }
  }

  // FIXED: Crash due to unsafe Map casting on iOS
  Future<void> loadDeliverySlots() async {
    if (!CartService.isAuthenticated()) return;

    // 1. CACHE HIT: If we have data in memory, show it INSTANTLY
    if (_memoryCachedSlots != null && _memoryCachedSlots!.isNotEmpty) {
      if (mounted) {
        setState(() {
          slotsByDate = _memoryCachedSlots!;
          availableSlots = _memoryCachedAvailableSlots ?? [];
          isLoadingSlots = false; // Stop spinner immediately

          // Pre-select logic (restored from your original code)
          if (_selectedDateKey == null && slotsByDate.isNotEmpty) {
            _selectedDateKey = slotsByDate.keys.first;
          }
          if (selectedSlotId == null && availableSlots.isNotEmpty) {
            final firstAvailableSlot = availableSlots.firstWhere(
                  (slot) => slot['isAvailable'] == true,
              orElse: () => <String, dynamic>{},
            );
            if (firstAvailableSlot.isNotEmpty) {
              selectedSlotId = firstAvailableSlot['id'];
              selectedSlotData = firstAvailableSlot;
              _selectedDateKey = firstAvailableSlot['dateFormatted'];
            }
          }
        });
      }
    } else {
      // 2. CACHE MISS: Only show spinner if we have NO data
      if (mounted) {
        setState(() {
          isLoadingSlots = true;
        });
      }
    }

    try {
      // 3. NETWORK REFRESH: Fetch fresh data in the background
      // We removed 'CartService.clearDeliverySlotsCache()' to allow HTTP caching if supported

      final slotsResult = await CartService.getSlotsByDate();

      if (mounted && slotsResult['success'] == true) {
        final slotsData = slotsResult['data'];
        final rawSlotsMap = slotsData['slotsByDate'];

        // Safe Manual Mapping for iOS
        Map<String, List<Map<String, dynamic>>> safeSlotsByDate = {};
        if (rawSlotsMap is Map) {
          rawSlotsMap.forEach((key, value) {
            if (value is List) {
              safeSlotsByDate[key.toString()] = value.map((e) {
                return Map<String, dynamic>.from(e as Map);
              }).toList();
            }
          });
        }

        final newAvailableSlots = <Map<String, dynamic>>[];
        safeSlotsByDate.values.forEach((dateSlots) {
          newAvailableSlots.addAll(dateSlots);
        });

        // 4. UPDATE MEMORY CACHE
        _memoryCachedSlots = safeSlotsByDate;
        _memoryCachedAvailableSlots = newAvailableSlots;
        _lastSlotsFetchTime = DateTime.now();

        // 5. UPDATE UI with fresh data
        setState(() {
          slotsByDate = safeSlotsByDate;
          availableSlots = newAvailableSlots;
          isLoadingSlots = false;

          // Re-run selection logic only if nothing is selected yet
          if (selectedSlotId == null) {
            if (_selectedDateKey == null && slotsByDate.isNotEmpty) {
              _selectedDateKey = slotsByDate.keys.first;
            }
            final firstAvailableSlot = availableSlots.firstWhere(
                  (slot) => slot['isAvailable'] == true,
              orElse: () => <String, dynamic>{},
            );
            if (firstAvailableSlot.isNotEmpty) {
              selectedSlotId = firstAvailableSlot['id'];
              selectedSlotData = firstAvailableSlot;
              _selectedDateKey = firstAvailableSlot['dateFormatted'];
            }
          }
        });

        _startSlotsAutoRefresh();
      } else {
        if (mounted) {
          setState(() {
            isLoadingSlots = false;
          });
        }
      }
    } catch (e) {
      print("Error loading slots: $e");
      if (mounted) {
        setState(() {
          isLoadingSlots = false;
        });
      }
    }
  }

  void _startSlotsAutoRefresh() {
    _slotsRefreshTimer?.cancel();
    if (!_isAutoRefreshEnabled) return;

    _slotsRefreshTimer = Timer.periodic(const Duration(seconds: 05), (timer) {
      if (mounted && !isInstantDelivery && showSlotSelection) {
        _refreshSlotsInBackground();
      }
    });
  }

  // FIXED: Crash due to unsafe Map casting on iOS (Background refresh)
  Future<void> _refreshSlotsInBackground() async {
    if (!CartService.isAuthenticated()) return;

    try {
      CartService.clearDeliverySlotsCache();
      final slotsResult = await CartService.getSlotsByDate();

      if (mounted && slotsResult['success'] == true) {
        final slotsData = slotsResult['data'];
        final rawSlotsMap = slotsData['slotsByDate'];

        // --- FIX START: Safe Manual Mapping ---
        Map<String, List<Map<String, dynamic>>> safeSlotsByDate = {};

        if (rawSlotsMap is Map) {
          rawSlotsMap.forEach((key, value) {
            if (value is List) {
              safeSlotsByDate[key.toString()] = value.map((e) {
                return Map<String, dynamic>.from(e as Map);
              }).toList();
            }
          });
        }
        // --- FIX END ---

        setState(() {
          slotsByDate = safeSlotsByDate;

          availableSlots = [];
          slotsByDate.values.forEach((dateSlots) {
            availableSlots.addAll(dateSlots);
          });

          if (selectedSlotId != null) {
            final selectedSlotStillExists = availableSlots.any(
                  (slot) => slot['id'] == selectedSlotId,
            );

            if (!selectedSlotStillExists) {
              final firstAvailableSlot = availableSlots.firstWhere(
                    (slot) => slot['isAvailable'] == true,
                orElse: () => <String, dynamic>{},
              );

              if (firstAvailableSlot.isNotEmpty) {
                selectedSlotId = firstAvailableSlot['id'];
                selectedSlotData = firstAvailableSlot;
                _selectedDateKey = firstAvailableSlot['dateFormatted'];

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your selected slot became unavailable. We selected a new slot for you.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange.shade600,
                  ),
                );
              } else {
                selectedSlotId = null;
                selectedSlotData = null;
              }
            }
          }
        });
      }
    } catch (e) {
      print('Background slot refresh failed: $e');
    }
  }

  void _stopSlotsAutoRefresh() {
    _slotsRefreshTimer?.cancel();
    _slotsRefreshTimer = null;
  }

  /*oid _toggleAutoRefresh(bool enabled) {
    setState(() {
      _isAutoRefreshEnabled = enabled;
    });

    if (enabled) {
      _startSlotsAutoRefresh();
    } else {
      _stopSlotsAutoRefresh();
    }
  }*/

  Future<void> _getCurrentLocationAndFillAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      throw Exception('Failed to get location. Please try again.');
    }

    List<Placemark> placemarks;
    try {
      placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } on PlatformException catch (e) {
      throw Exception('Failed to get address from location: ${e.message}');
    } catch (e) {
      throw Exception('Error getting address: $e');
    }

    if (placemarks.isEmpty) {
      throw Exception('No address found for your current location.');
    }

    Placemark place = placemarks[0];

    // FIXED: Typo in String Interpolation for location URL
    setState(() {
      _houseNoController.text =
      '${place.name ?? ''} ${place.thoroughfare ?? ''}';
      _areaController.text = place.subLocality ?? place.locality ?? '';
      _cityController.text = place.locality ?? place.administrativeArea ?? '';
      _stateController.text = place.administrativeArea ?? '';
      _postalCodeController.text = place.postalCode ?? '';
      // Corrected the URL string below
      _locationController.text =
      'maps.google.com/?q=${position.latitude},${position.longitude}';

      selectedAddress = null;
      _showAddressForm = true;
    });
  }

  Future<void> _updateDeliveryFee() async {
    final feeResult = await CartService.calculateDeliveryFee(totalAmount);

    if (mounted) {
      setState(() {
        deliveryFee = (feeResult['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        handlingFee = (feeResult['handlingFee'] as num?)?.toDouble() ?? 0.0;
        isFreeDelivery = feeResult['isFreeDelivery'] as bool? ?? false;

        deliveryFeeName =
            feeResult['deliveryFeeName']?.toString() ?? 'Delivery Charge';
        handlingFeeName =
            feeResult['handlingFeeName']?.toString() ?? 'Processing Fee';

        thresholdAmount =
            (feeResult['thresholdAmount'] as num?)?.toDouble() ?? 0.0;
        thresholdMessage = feeResult['thresholdMessage']?.toString() ??
            'Free delivery on orders above ₹${thresholdAmount.toStringAsFixed(0)}';

        if (feeResult['error'] != null) {
          deliveryFee = 0.0;
          handlingFee = 0.0;
          isFreeDelivery = true;
          thresholdMessage = 'Could not load delivery fees.';
        }
      });
    }
  }

  Future<void> loadPopularProducts() async {
    if (!mounted) return;

    setState(() {
      isLoadingPopularProducts = true;
    });

    try {
      final products = await ApiService.getPopularProducts(limit: 8);

      if (mounted) {
        setState(() {
          popularProducts = products;
          isLoadingPopularProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          popularProducts = [];
          isLoadingPopularProducts = false;
        });
      }
    }
  }

  Future<void> loadCart() async {
    if (!mounted) return;

    if (_outOfStockItemIds.isNotEmpty) {
      setState(() {
        _outOfStockItemIds.clear();
      });
    }

    errorMessage = null;

    try {
      final cached = await CartService.readCartFromCache();
      if (cached != null) {
        final itemsData = cached['items'] as List<dynamic>? ?? [];

        final newCartItems = itemsData.map((item) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          return CartItem.fromJson(itemMap);
        }).toList();

        final double parsedAmount = (cached['totalAmount'] is num)
            ? (cached['totalAmount'] as num).toDouble()
            : (double.tryParse(cached['totalAmount']?.toString() ?? '') ??
            0.0);
        final double parsedItems = (cached['totalItems'] is num)
            ? (cached['totalItems'] as num).toDouble()
            : (double.tryParse(cached['totalItems']?.toString() ?? '') ?? 0.0);

        if (!mounted) return;
        setState(() {
          cartItems = newCartItems;
          totalAmount = parsedAmount;
          totalItems = parsedItems;
          isLoading = false;
        });

        try {
          final Map<String, int> providerMap = {};
          for (final ci in newCartItems) {
            providerMap[ci.itemId] =
                (providerMap[ci.itemId] ?? 0) + ci.quantity;
          }
          Provider.of<CartProvider>(
            context,
            listen: false,
          ).setCartItems(providerMap);
        } catch (e) {
          print('Failed to sync CartProvider: $e');
        }

        _refreshCartNetworkAndUpdate();
        await _updateDeliveryFee();
        await _validateCartItemsStock(newCartItems);

        if (newCartItems.isNotEmpty && !_hasShownSwipeHint) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showSwipeHintForFirstItem();
          });
        }

        return;
      }
    } catch (e) {
      print('⚠️ Failed to read cached cart: $e');
    }

    setState(() {
      isLoading = true;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final response = await CartService.getCart();
      if (!mounted) return;

      stopwatch.stop();

      if (response != null && response['error'] == null) {
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          final itemsData = data['items'] as List<dynamic>? ?? [];

          final double parsedAmount = (data['totalAmount'] is String
              ? double.tryParse(data['totalAmount'] as String)
              : (data['totalAmount'] as num?)?.toDouble()) ??
              0.0;
          final double parsedItems = (data['totalItems'] is String
              ? double.tryParse(data['totalItems'] as String)
              : (data['totalItems'] as num?)?.toDouble()) ??
              0.0;

          final newCartItems = itemsData.map((item) {
            final itemMap = item as Map<String, dynamic>;
            return CartItem.fromJson(itemMap);
          }).toList();

          if (!mounted) return;
          setState(() {
            cartItems = newCartItems;
            totalAmount = parsedAmount;
            totalItems = parsedItems;
            isLoading = false;
          });

          try {
            final Map<String, int> providerMap = {};
            for (final ci in newCartItems) {
              providerMap[ci.itemId] =
                  (providerMap[ci.itemId] ?? 0) + ci.quantity;
            }
            Provider.of<CartProvider>(
              context,
              listen: false,
            ).setCartItems(providerMap);
            await CartService.saveCartToCache(data);
          } catch (e) {
            print('Failed to sync/cache cart: $e');
          }

          await _updateDeliveryFee();
          await _validateCartItemsStock(newCartItems);

          if (newCartItems.isNotEmpty && !_hasShownSwipeHint) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _showSwipeHintForFirstItem();
            });
          }
        } else {
          if (!mounted) return;
          setState(() {
            isLoading = false;
            errorMessage =
                response['message']?.toString() ?? 'No cart data available';
            cartItems = [];
            totalAmount = 0.0;
            totalItems = 0.0;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage =
              response?['error']?.toString() ?? 'Failed to load cart';
          cartItems = [];
          totalAmount = 0.0;
          totalItems = 0.0;
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading cart: $e';
          cartItems = [];
          totalAmount = 0.0;
          totalItems = 0.0;
        });
      }
    }
  }

  Future<void> _refreshCartNetworkAndUpdate() async {
    try {
      final response = await CartService.getCart();
      if (response != null &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>? ?? [];

        final newCartItems = itemsData.map((item) {
          final itemMap = item as Map<String, dynamic>;
          return CartItem.fromJson(itemMap);
        }).toList();

        if (!mounted) return;
        setState(() {
          cartItems = newCartItems;
          totalAmount = (data['totalAmount'] is num)
              ? (data['totalAmount'] as num).toDouble()
              : (double.tryParse(data['totalAmount']?.toString() ?? '') ?? 0.0);
          totalItems = (data['totalItems'] is num)
              ? (data['totalItems'] as num).toDouble()
              : (double.tryParse(data['totalItems']?.toString() ?? '') ?? 0.0);
        });

        try {
          final Map<String, int> providerMap = {};
          for (final ci in newCartItems) {
            providerMap[ci.itemId] =
                (providerMap[ci.itemId] ?? 0) + ci.quantity;
          }
          Provider.of<CartProvider>(
            context,
            listen: false,
          ).setCartItems(providerMap);
          await CartService.saveCartToCache(data);
        } catch (e) {
          print('⚠️ Failed to update/cache cart after background refresh: $e');
        }

        await _updateDeliveryFee();
      }
    } catch (e) {
      print('⚠️ Background cart refresh failed: $e');
    }
  }

  Future<void> fetchWalletBalance() async {
    try {
      final userData = UserData();
      final userId = userData.getUserId();
      final token = userData.getToken();

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            walletPoints = 0;
          });
        }
        return;
      }

      if (mounted) setState(() => isWalletLoading = true);
      final resp = await WalletApiService.getBalance(
        customerId: userId,
        token: token,
      );

      int parsedPoints = 0;
      if (resp != null) {
        final data = resp['data'] as Map<String, dynamic>?;
        if (data != null) {
          final dynamic p =
              data['pointsBalance'] ?? data['points'] ?? data['points_balance'];
          if (p is int) parsedPoints = p;
          if (p is String) parsedPoints = int.tryParse(p) ?? 0;
          if (p is double) parsedPoints = p.toInt();
        }
      }

      if (mounted) {
        setState(() {
          walletPoints = parsedPoints;
          isWalletLoading = false;
        });
      }
    } catch (e) {
      print('Failed to fetch wallet balance: $e');
      if (mounted) setState(() => isWalletLoading = false);
    }
  }

  Future<void> updateQuantity(CartItem item, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(item);
      return;
    }

    try {
      if (!isLoading) {
        setState(() {
          isLoading = true;
        });
      }

      if (newQuantity > item.quantity) {
        final stock = await StockService.getItemStock(item.itemId);

        if (stock == null) {
          if (mounted) {
            _showErrorMessage('Could not verify stock. Please try again.');
            setState(() {
              isLoading = false;
            });
          }
          return;
        }

        if (newQuantity > stock.currentStock) {
          if (mounted) {
            if (stock.currentStock == 0) {
              _showErrorMessage('${item.itemName} is out of stock');
            } else {
              _showErrorMessage(
                'Only ${stock.currentStock} in stock for ${item.itemName}',
              );
            }
            setState(() {
              isLoading = false;
            });
          }
          return;
        }
      }

      final response = await CartService.updateItemQuantity(
        cartItemId: item.id,
        itemId: item.itemId,
        quantity: newQuantity,
      );

      if (response != null && response['error'] == null) {
        await loadCart();
      } else {
        if (mounted) {
          String errorMsg = response?['message'] ??
              response?['error'] ??
              'Failed to update cart';
          _showErrorMessage(errorMsg);
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorMessage('Error updating quantity: $e');
      }
    }
  }

  Future<void> removeItem(CartItem item) async {
    try {
      if (!isLoading) {
        setState(() {
          isLoading = true;
        });
      }

      final response = await CartService.removeItemFromCart(
        cartItemId: item.id,
        itemId: item.itemId,
      );

      if (response != null && response['error'] == null) {
        await loadCart();
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  double get currentDeliveryFee => deliveryFee;

  double get grandTotal {
    double total =
        totalAmount + deliveryFee + handlingFee + selectedTip + selectedDonation;
    return total - couponDiscountAmount;
  }

  void updateTip(String amount, double value) {
    setState(() {
      selectedTip = value;
      selectedTipAmount = amount;
    });
  }

  void _onCouponApplied(CouponModel? coupon, [double serverDiscount = 0.0]) {
    setState(() {
      selectedCoupon = coupon;

      if (coupon == null) {
        couponDiscountAmount = 0.0;
      } else {
        // Use the value returned by the API (serverDiscount)
        // The server logic now handles exclusions, percentage vs fixed, and limits.
        couponDiscountAmount = serverDiscount;

        // Safety check to ensure discount doesn't exceed total
        if (couponDiscountAmount > totalAmount) {
          couponDiscountAmount = totalAmount;
        }
      }
    });
  }
  void updateDonation(String amount, double value) {
    setState(() {
      selectedDonation = value;
      selectedDonationAmount = amount;
    });
  }

  void updateDeliveryType(bool instant) {
    setState(() {
      isInstantDelivery = instant;
      if (!instant) {
        showSlotSelection = true;
        _startSlotsAutoRefresh();
      } else {
        showSlotSelection = false;
        selectedSlotId = null;
        selectedSlotData = null;
        _stopSlotsAutoRefresh();
      }
    });
    _updateDeliveryFee();
  }

  void selectDeliverySlot(Map<String, dynamic> slot) {
    setState(() {
      selectedSlotId = slot['id'];
      selectedSlotData = slot;
      _selectedDateKey = slot['dateFormatted'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Slot selected: ${slot['displayText']}')),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showOutOfStockDialog(
      List<Map<String, dynamic>> unavailableItemsList,
      ) async {
    String outOfStockMessage;
    List<String> unavailableItemIds = [];

    try {
      if (unavailableItemsList.isEmpty) return;

      for (var item in unavailableItemsList) {
        final itemId = item['item']?.toString();
        if (itemId != null) {
          unavailableItemIds.add(itemId);
        }
      }

      if (unavailableItemsList.length == 1) {
        CartItem? unavailableCartItem;
        try {
          unavailableCartItem = cartItems.firstWhere(
                (item) => item.itemId == unavailableItemIds[0],
          );
          outOfStockMessage =
          "'${unavailableCartItem.itemName}' just went out of stock! Your cart will be refreshed.";
        } catch (e) {
          outOfStockMessage =
          'An item in your cart just went out of stock! Your cart will be refreshed.';
        }
      } else {
        outOfStockMessage =
        'Some items in your cart just went out of stock! Your cart will be refreshed.';
      }
    } catch (e) {
      outOfStockMessage = 'One or more items in your cart are now out of stock.';
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/error.json',
              height: 150,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Item Unavailable',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              outOfStockMessage,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (unavailableItemIds.isNotEmpty) {
                  setState(() {
                    _outOfStockItemIds = unavailableItemIds;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK, Refresh Cart'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isRedeeming = false;

  Future<void> _redeemNow() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }

    final userData = UserData();
    final userId = userData.getUserId();
    final token = userData.getToken();

    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to redeem points')),
      );
      return;
    }

    final spendAmount = totalAmount.toInt();
    final itemIds =
    cartItems.map((c) => c.itemId).where((s) => s.isNotEmpty).toList();

    if (itemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid item ids found in cart')),
      );
      return;
    }

    setState(() => _isRedeeming = true);
    try {
      final resp = await WalletApiService.redeemPoints(
        customerId: userId,
        spendAmount: spendAmount,
        itemIds: itemIds,
        token: token,
      );

      final bool success = resp['success'] == true;
      final String message = resp['message']?.toString() ??
          (success ? 'Redeemed successfully' : 'Failed to redeem');

      Map<String, dynamic>? data;
      if (resp['data'] is Map) {
        data = resp['data'] as Map<String, dynamic>;
      }

      final double? discountAmount = data?['discountAmount'] is num
          ? (data!['discountAmount'] as num).toDouble()
          : null;

      final int? pointsUsed = data?['pointsUsed'] is num
          ? (data!['pointsUsed'] as num).toInt()
          : null;

      if (discountAmount != null && pointsUsed != null) {
        setState(() {
          _lastDiscountAmount = discountAmount;
          _isRedeemed = true;
        });
        _showRedemptionSuccessDialog(
          pointsUsed: pointsUsed,
          discountAmount: discountAmount,
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (success) {
        await loadCart();
        await fetchWalletBalance();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error redeeming points: $e')));
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  void _showRedemptionSuccessDialog({
    required int pointsUsed,
    required double discountAmount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[600]!, Colors.green[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Points Redeemed!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Successfully applied to your order',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.stars_rounded,
                                color: Colors.amber[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Points Used',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$pointsUsed pts',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.currency_rupee,
                                color: Colors.green[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Discount Applied',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹$discountAmount',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'SAVED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Discount will be reflected in your final bill',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue Shopping',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
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
      },
    );
  }

  Future<void> _loadDefaultAddressAndUserData() async {
    _houseNoController.clear();
    _areaController.clear();
    _cityController.clear();
    _stateController.clear();
    _postalCodeController.clear();
    _locationController.clear();

    setState(() {
      isLoadingAddresses = true;
    });

    bool addressesFound = false;

    try {
      final cached = await AddressService.readAddressesFromCache();
      if (cached != null && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          savedAddresses = cached;
        });

        Address? defaultAddress;
        try {
          defaultAddress = cached.firstWhere((addr) => addr.isDefault);
        } catch (e) {
          defaultAddress = cached.first;
        }

        if (defaultAddress != null) {
          setState(() {
            selectedAddress = defaultAddress;
            _showAddressForm = false;
          });
          _fillAddressForm(defaultAddress);
          addressesFound = true;
        }
        _refreshAddressesNetworkAndUpdate();
      } else {
        final addresses = await AddressService.fetchAddresses();
        if (mounted && addresses.isNotEmpty) {
          setState(() {
            savedAddresses = addresses;
          });

          Address? defaultAddress;
          try {
            defaultAddress = addresses.firstWhere((addr) => addr.isDefault);
          } catch (e) {
            defaultAddress = addresses.first;
            print("No default address found, using first address.");
          }

          if (defaultAddress != null) {
            setState(() {
              selectedAddress = defaultAddress;
              _showAddressForm = false;
            });
            _fillAddressForm(defaultAddress);
            addressesFound = true;
          }
        }
      }
    } catch (e) {
      print("Error loading saved addresses: $e");
    }

    if (mounted) {
      setState(() {
        isLoadingAddresses = false;
      });
    }

    if (!addressesFound) {
      if (mounted) {
        setState(() {
          _showAddressForm = true;
          savedAddresses = [];
        });
      }

      try {
        await _getCurrentLocationAndFillAddress();
      } catch (e) {
        if (mounted) {
          final userData = UserData();
          final user = userData.getCurrentUser();
          if (user != null) {
            _cityController.text = user.city ?? userData.getCity() ?? '';
            _stateController.text = user.state ?? userData.getState() ?? '';
          }
        }
        _showErrorMessage(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _refreshAddressesNetworkAndUpdate() async {
    try {
      final fresh = await AddressService.fetchAddresses();
      if (fresh.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          savedAddresses = fresh;
          isLoadingAddresses = false;
        });

        try {
          await AddressService.saveAddressesToCache(fresh);
        } catch (e) {
          print('⚠️ Failed to cache addresses after refresh: $e');
        }
      }
    } catch (e) {
      print('⚠️ Background address refresh failed: $e');
    }
  }

  void _fillAddressForm(Address address) {
    setState(() {
      _houseNoController.text = address.street ?? '';
      _areaController.text = address.area ?? '';
      _cityController.text = address.city ?? '';
      _stateController.text = address.state ?? '';
      _postalCodeController.text = address.postalCode ?? '';
    });
  }

  void _prepareAndShowCheckoutPopup() async {
    setState(() {
      _isPreparingCheckout = true;
    });

    await _loadDefaultAddressAndUserData();

    setState(() {
      _isPreparingCheckout = false;
    });

    if (mounted) {
      _showCheckoutPopup();
    }
  }

  void _showCheckoutPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !_isCheckoutLoading && !_isProcessingPayment,
      enableDrag: !_isCheckoutLoading && !_isProcessingPayment,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => WillPopScope(
          onWillPop: () async => !_isCheckoutLoading && !_isProcessingPayment,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Complete Your Order',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_isCheckoutLoading && !_isProcessingPayment)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPopupOrderSummary(),
                          const SizedBox(height: 20),
                          if (!isInstantDelivery && selectedSlotData != null)
                            _buildSelectedSlotInfo(),
                          if (!isInstantDelivery && selectedSlotData != null)
                            const SizedBox(height: 20),
                          _buildPopupAddressForm(),
                          const SizedBox(height: 20),
                          _buildPopupPaymentMethod(setModalState),
                          const SizedBox(height: 20),
                          _buildPopupPriceSummary(),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCheckoutLoading || _isProcessingPayment
                          ? null
                          : () async {
                        final isFormValid =
                        _formKey.currentState!.validate();

                        if (!isFormValid) {
                          _showErrorMessage(
                            'Please fill all required fields',
                          );
                          return;
                        }

                        if (!isInstantDelivery &&
                            selectedSlotId == null) {
                          _showErrorMessage(
                            'Please select a delivery slot',
                          );
                          return;
                        }

                        if (selectedPaymentMethod == 'Online') {
                          setModalState(() {
                            _isCheckoutLoading = true;
                          });

                          List<Map<String, dynamic>>
                          allUnavailableItems = [];

                          for (final item in cartItems) {
                            final stock = await StockService.getItemStock(
                              item.itemId,
                            );
                            if (stock == null) {
                              _showErrorMessage(
                                'Could not verify stock. Please try again.',
                              );
                              setModalState(
                                    () => _isCheckoutLoading = false,
                              );
                              return;
                            }
                            if (item.quantity > stock.currentStock) {
                              allUnavailableItems.add({
                                'item': item.itemId,
                              });
                            }
                          }

                          if (allUnavailableItems.isNotEmpty) {
                            setModalState(
                                  () => _isCheckoutLoading = false,
                            );

                            if (mounted) Navigator.pop(context);
                            await _showOutOfStockDialog(
                              allUnavailableItems,
                            );

                            setState(
                                  () => _isCheckoutLoading = false,
                            );

                            return;
                          } else {
                            setModalState(
                                  () => _isCheckoutLoading = false,
                            );

                            if (mounted) Navigator.pop(context);
                            Future.delayed(
                              Duration(milliseconds: 300),
                                  () {
                                _openRazorpayCheckout();
                              },
                            );
                          }
                        } else {
                          setModalState(() {
                            _isCheckoutLoading = true;
                          });

                          List<Map<String, dynamic>>
                          allUnavailableItems = [];

                          for (final item in cartItems) {
                            final stock = await StockService.getItemStock(
                              item.itemId,
                            );
                            if (stock == null) {
                              _showErrorMessage(
                                'Could not verify stock. Please try again.',
                              );
                              setModalState(
                                    () => _isCheckoutLoading = false,
                              );
                              return;
                            }
                            if (item.quantity > stock.currentStock) {
                              allUnavailableItems.add({
                                'item': item.itemId,
                              });
                            }
                          }

                          if (allUnavailableItems.isNotEmpty) {
                            setModalState(
                                  () => _isCheckoutLoading = false,
                            );

                            if (mounted) Navigator.pop(context);
                            await _showOutOfStockDialog(
                              allUnavailableItems,
                            );

                            setState(
                                  () => _isCheckoutLoading = false,
                            );

                            return;
                          } else {
                            _placeOrderFromPopup(setModalState);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade800,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCheckoutLoading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Processing Order...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                          : _isProcessingPayment
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Opening Payment...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                          : Text(
                        'Place Order - ₹${(grandTotal - (_lastDiscountAmount ?? 0)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _buildSelectedSlotInfo() {
    if (selectedSlotData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.schedule, color: Colors.green.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Delivery Slot',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedSlotData!['displayText'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                showSlotSelection = true;
              });
            },
            child: Text(
              'Change',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupOrderSummary() {
    return OrderSummaryWidget(
      cartItems: cartItems,
      buildProductImage: _buildProductImage,
    );
  }

  Widget _buildPopupAddressForm() {
    final uniqueSavedAddresses = savedAddresses.toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uniqueSavedAddresses.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: Colors.brown),
              const SizedBox(width: 8),
              const Text(
                'Delivery Address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Address>(
                isExpanded: true,
                value: selectedAddress,
                hint: const Text('Select a saved address'),
                icon: Icon(Icons.arrow_drop_down, color: Colors.brown.shade800),
                items: [
                  ...uniqueSavedAddresses.map((address) {
                    return DropdownMenuItem<Address>(
                      value: address,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        address.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (address.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${address.street}, ${address.area}, ${address.city}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  DropdownMenuItem<Address>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.brown.shade800),
                        const SizedBox(width: 8),
                        Text(
                          'Add New Address',
                          style: TextStyle(
                            color: Colors.brown.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      selectedAddress = value;
                      _fillAddressForm(value);
                      _showAddressForm = false;
                    } else {
                      selectedAddress = null;
                      _houseNoController.clear();
                      _areaController.clear();
                      _cityController.clear();
                      _stateController.clear();
                      _postalCodeController.clear();
                      _locationController.clear();
                      _showAddressForm = true;
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 24),
        ],
        if (isLoadingAddresses)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.brown.shade800),
            ),
          ),
        if (!isLoadingAddresses) ...[
          if (_showAddressForm) ...[
            const SizedBox(height: 12),
            AddressFormWidget(
              houseNoController: _houseNoController,
              areaController: _areaController,
              cityController: _cityController,
              stateController: _stateController,
              postalCodeController: _postalCodeController,
              locationController: _locationController,
            ),
          ],
        ],
      ],
    );
  }

  String selectedPaymentMethod = 'Online';

  Widget _buildPopupPaymentMethod(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.payment, size: 20, color: Colors.brown),
            const SizedBox(width: 8),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isProcessingPayment
              ? null
              : () {
            setState(() {
              selectedPaymentMethod = 'Online';
            });
            setModalState(() {
              selectedPaymentMethod = 'Online';
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selectedPaymentMethod == 'Online'
                  ? Colors.brown.shade50
                  : Colors.grey.shade50,
              border: Border.all(
                color: selectedPaymentMethod == 'Online'
                    ? Colors.brown.shade800
                    : Colors.grey.shade300,
                width: selectedPaymentMethod == 'Online' ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedPaymentMethod == 'Online'
                        ? Colors.brown.shade800
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selectedPaymentMethod == 'Online'
                              ? Colors.brown.shade700
                              : Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Pay ₹${grandTotal.toStringAsFixed(2)} via UPI, Card or Net Banking',
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedPaymentMethod == 'Online'
                              ? Colors.brown.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selectedPaymentMethod == 'Online'
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selectedPaymentMethod == 'Online'
                      ? Colors.brown.shade800
                      : Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!_isRedeemed)
          GestureDetector(
            onTap: _isProcessingPayment
                ? null
                : () {
              setState(() {
                selectedPaymentMethod = 'COD';
              });
              setModalState(() {
                selectedPaymentMethod = 'COD';
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selectedPaymentMethod == 'COD'
                    ? Colors.brown.shade50
                    : Colors.grey.shade50,
                border: Border.all(
                  color: selectedPaymentMethod == 'COD'
                      ? Colors.brown.shade800
                      : Colors.grey.shade300,
                  width: selectedPaymentMethod == 'COD' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selectedPaymentMethod == 'COD'
                          ? Colors.brown.shade800
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.money,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash on Delivery',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedPaymentMethod == 'COD'
                                ? Colors.brown.shade700
                                : Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Pay ₹${grandTotal.toStringAsFixed(2)} when order arrives',
                          style: TextStyle(
                            fontSize: 12,
                            color: selectedPaymentMethod == 'COD'
                                ? Colors.brown.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selectedPaymentMethod == 'COD'
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selectedPaymentMethod == 'COD'
                        ? Colors.brown.shade800
                        : Colors.grey.shade400,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _validateCartItemsStock(List<CartItem> items) async {
    if (items.isEmpty) {
      if (_outOfStockItemIds.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _outOfStockItemIds.clear();
        });
      }
      return;
    }

    List<String> unavailableIds = [];

    final stockChecks = items.map((item) async {
      try {
        final stock = await StockService.getItemStock(item.itemId);

        if (stock != null && item.quantity > stock.currentStock) {
          return item.itemId;
        }
      } catch (e) {
        print('Error checking stock for ${item.itemId}: $e');
      }
      return null;
    }).toList();

    final results = await Future.wait(stockChecks);

    unavailableIds = results.whereType<String>().toList();

    if (mounted) {
      setState(() {
        _outOfStockItemIds = unavailableIds;
      });

      if (unavailableIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Some items in your cart are out of stock.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRazorpayPaymentSuccess(
      PaymentSuccessResponse response,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.brown.shade800),
                const SizedBox(height: 16),
                const Text('Processing payment...'),
              ],
            ),
          ),
        ),
      );

      final userData = UserData();
      final user = userData.getCurrentUser();

      if (user == null || !user.isLoggedIn) {
        if (!mounted) return;
        Navigator.pop(context);
        _showLoginRequiredDialog();
        return;
      }

      if (totalAmount <= 0 || grandTotal <= 0) {
        if (!mounted) return;
        Navigator.pop(context);
        _showErrorMessage('Invalid order amount');
        return;
      }

      final orderResponse = await OrderService.createOrder(
        customerName: user.name ?? 'Customer',
        phoneNumber: user.phone ?? '',
        email: user.email ?? '',
        houseNo: _houseNoController.text.trim(),
        area: _areaController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        locationLink: _locationController.text.trim(),
        discountApplied: couponDiscountAmount,
        couponCode: selectedCoupon?.code,
        couponDiscount: couponDiscountAmount,
        deliverySlotId: selectedSlotId,
        deliverySlotInfo: selectedSlotData,
        isInstantDelivery: isInstantDelivery,
        subtotal: totalAmount,
        deliveryCharge: deliveryFee,
        processingFee: handlingFee,
        tip: selectedTip,
        donation: selectedDonation,
        totalAmount: grandTotal,
        paymentMethod: 'Online',
        paymentStatus: 'Paid',
        tax: 0.0,
        razorpayPaymentId: response.paymentId,
        razorpayOrderId: response.orderId,
        razorpaySignature: response.signature,
      );

      if (!mounted) return;
      Navigator.pop(context);

      List<dynamic> unavailableItemsList = orderResponse['unavailable'] ?? [];

      if (unavailableItemsList.isNotEmpty) {
        await _showOutOfStockDialog(
          unavailableItemsList.cast<Map<String, dynamic>>(),
        );

        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
        }

        _showErrorMessage(
          'Item(s) out of stock! Your payment was successful, please contact support for a refund.',
        );
      } else if (orderResponse['success'] == true ||
          orderResponse['data'] != null) {
        final orderData =
            orderResponse['data'] ?? orderResponse['order'] ?? orderResponse;
        _lastOrderId =
            orderData['_id']?.toString() ?? orderData['id']?.toString();
        _lastOrderNumber = orderData['orderNumber']?.toString() ??
            'ORD${DateTime.now().millisecondsSinceEpoch}';

        if (_lastOrderId != null) {
          await OrderService.sendPaymentConfirmation(
            orderId: _lastOrderId!,
            amount: grandTotal,
            paymentMethod: 'Razorpay',
          );
        }

        if (!mounted) return;
        await _showSuccessDialog();
        await loadCart();
      } else {
        String errorMsg = _extractErrorMessage(orderResponse);
        _showErrorMessage('Order placement failed: $errorMsg');

        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      String errorMsg = e.toString().replaceAll('Exception: ', '');

      _showErrorMessage('Failed to complete order: $errorMsg');

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  Widget _buildPopupPriceSummary() {
    return PriceSummaryWidget(
      totalAmount: totalAmount,
      deliveryFee: deliveryFee,
      handlingFee: handlingFee,
      deliveryFeeName: deliveryFeeName,
      handlingFeeName: handlingFeeName,
      selectedTip: selectedTip,
      selectedDonation: selectedDonation,
      grandTotal: grandTotal,
      isFreeDelivery: isFreeDelivery,
      thresholdMessage: thresholdMessage,
      thresholdAmount: thresholdAmount,
      discountAmount: _lastDiscountAmount ?? 0.0,
      couponDiscount: couponDiscountAmount,
    );
  }

  Future<void> _placeOrderFromPopup(StateSetter setModalState) async {
    if (!_formKey.currentState!.validate()) {
      _showErrorMessage('Please fill all required fields');
      return;
    }

    if (!isInstantDelivery && selectedSlotId == null) {
      _showErrorMessage('Please select a delivery slot');
      return;
    }

    if (selectedPaymentMethod == 'Online') {
      _showErrorMessage('Please complete the payment to place your order');
      return;
    }

    setModalState(() => _isCheckoutLoading = true);

    bool isPopping = false;

    try {
      final userData = UserData();
      final user = userData.getCurrentUser();

      if (user == null ||
          !user.isLoggedIn ||
          user.token == null ||
          user.token!.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        _showLoginRequiredDialog();
        return;
      }

      if (cartItems.isEmpty) {
        _showErrorMessage('Your cart is empty');
        return;
      }

      final warehouseId = user.selectedWarehouseId;

      if (warehouseId == null || warehouseId.isEmpty) {
        _showErrorMessage(
          'Warehouse not assigned. Please check your delivery location.',
        );
        setModalState(() => _isCheckoutLoading = false);
        return;
      }

      if (totalAmount <= 0) {
        _showErrorMessage('Cart total cannot be zero or negative');
        setModalState(() => _isCheckoutLoading = false);
        return;
      }

      if (grandTotal <= 0) {
        _showErrorMessage('Order total cannot be zero or negative');
        setModalState(() => _isCheckoutLoading = false);
        return;
      }

      final orderResponse = await OrderService.createOrder(
        customerName: user.name ?? 'Customer',
        phoneNumber: user.phone ?? '',
        email: user.email ?? '',
        discountApplied: couponDiscountAmount,
        couponCode: selectedCoupon?.code,
        couponDiscount: couponDiscountAmount,
        houseNo: _houseNoController.text.trim(),
        area: _areaController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        locationLink: _locationController.text.trim(),
        deliverySlotId: selectedSlotId,
        deliverySlotInfo: selectedSlotData,
        isInstantDelivery: isInstantDelivery,
        subtotal: totalAmount,
        deliveryCharge: deliveryFee,
        processingFee: handlingFee,
        tip: selectedTip,
        donation: selectedDonation,
        totalAmount: grandTotal,
        paymentMethod: 'COD',
        paymentStatus: 'Pending',
        tax: 0.0,
      );

      if (!mounted) return;

      if (orderResponse['success'] == true ||
          orderResponse['data'] != null ||
          orderResponse['order'] != null) {
        isPopping = true;

        final orderData =
            orderResponse['data'] ?? orderResponse['order'] ?? orderResponse;
        _lastOrderId =
            orderData['_id']?.toString() ?? orderData['id']?.toString();
        _lastOrderNumber = orderData['orderNumber']?.toString() ??
            'ORD${DateTime.now().millisecondsSinceEpoch}';

        Navigator.pop(context);
        await _showSuccessDialog();

        if (!mounted) return;
        await loadCart();
      } else {
        List<dynamic> unavailableItemsList = orderResponse['unavailable'] ?? [];

        if (unavailableItemsList.isNotEmpty) {
          isPopping = true;

          if (mounted) Navigator.pop(context);

          await _showOutOfStockDialog(
            unavailableItemsList.cast<Map<String, dynamic>>(),
          );

          if (mounted) {
            setState(() {
              _isCheckoutLoading = false;
            });
          }
        } else {
          String errorMsg = _extractErrorMessage(orderResponse);
          if (mounted) {
            isPopping = true;
            Navigator.pop(context);
            _showFailureDialog('Order Failed', message: errorMsg);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      String errorMsg = e.toString().replaceAll('Exception: ', '');

      if (errorMsg.contains('Session expired') ||
          errorMsg.contains('Unauthorized') ||
          errorMsg.contains('Please login')) {
        Navigator.pop(context);
        _showLoginRequiredDialog();
      } else if (errorMsg.contains('Warehouse') &&
          errorMsg.contains('not assigned')) {
        _showErrorMessage('Please set your delivery location first');
      } else if (errorMsg.contains('"unavailable":') &&
          errorMsg.contains('"success":false')) {
        try {
          isPopping = true;

          final jsonString = errorMsg.substring(errorMsg.indexOf('{'));
          final errorJson = json.decode(jsonString) as Map<String, dynamic>;

          List<dynamic> unavailableItemsList = errorJson['unavailable'] ?? [];
          if (mounted) Navigator.pop(context);
          await _showOutOfStockDialog(
            unavailableItemsList.cast<Map<String, dynamic>>(),
          );

          if (mounted) {
            setState(() {
              _isCheckoutLoading = false;
            });
          }
        } catch (parseError) {
          isPopping = true;
          Navigator.pop(context);
          _showFailureDialog('Order Failed', message: errorMsg);
        }
      } else {
        isPopping = true;
        Navigator.pop(context);
        _showFailureDialog('Order Failed', message: errorMsg);
      }
    } finally {
      if (mounted && !isPopping) {
        setModalState(() => _isCheckoutLoading = false);
      }
    }
  }

  String _extractErrorMessage(Map<String, dynamic>? response) {
    if (response == null) return 'Unknown error occurred';

    return response['message'] ??
        response['error'] ??
        response['msg'] ??
        'Failed to create order. Please try again.';
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/placed.json',
              height: 150,
              repeat: false,
            ),
            const SizedBox(height: 20),
            const Text(
              'Order Placed Successfully!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_lastOrderNumber != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Order #$_lastOrderNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ₹${grandTotal.toStringAsFixed(2)} ($selectedPaymentMethod)',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    if (selectedSlotData != null && !isInstantDelivery)
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Delivery: ${selectedSlotData!['displayText']}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    if (isInstantDelivery)
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Delivery: Instant',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Your order has been placed successfully. You will receive a confirmation shortly.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue Shopping',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 30),
            const SizedBox(width: 12),
            const Text('Login Required'),
          ],
        ),
        content: const Text(
          'Your session has expired. Please login again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              NavigationService.goBackToHomeScreen();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login').then((_) {
                checkAuthAndLoadCart();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showFailureDialog(String title, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/failed.json',
                height: 120,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message ?? 'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are on iOS to conditionally enable standard swipe-to-back
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return PopScope(
      // On iOS, we MUST allow popping (canPop: true) to enable the swipe gesture.
      // On Android, we keep it false to intercept the back button and force your custom logic.
      canPop: isIOS,
      onPopInvoked: (didPop) {
        // If the system handled the pop (iOS swipe or manual pop), we just return.
        if (didPop) return;

        // This only runs on Android (since canPop is false there)
        NavigationService.goBackToHomeScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Checkout',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () {
              NavigationService.goBackToHomeScreen();
            },
          ),
          actions: [
            if (cartItems.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${cartItems.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (!isAuthenticated) ...[
              _buildUnauthenticatedView(),
            ] else if (isLoading && cartItems.isEmpty && errorMessage == null) ...[
              _buildLoadingOverlay(),
            ] else if (errorMessage != null && !isLoading) ...[
              _buildErrorView(),
            ] else if (cartItems.isEmpty && !isLoading) ...[
              _buildEmptyCartView(),
            ] else ...[
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cartItems.isNotEmpty) _buildCartItemsSection(),
                          if (cartItems.isNotEmpty)
                            (_isRedeemed)
                                ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[50]!,
                                      Colors.green[100]!.withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green[300]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green[700],
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Points Redeemed',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  color:
                                                  Colors.green[900],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                  Colors.green[600],
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(12),
                                                ),
                                                child: const Text(
                                                  'APPLIED',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Discount has been applied to your order',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.card_giftcard,
                                      color: Colors.green[600],
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            )
                                : (totalAmount < 2000.00)
                                ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange[50]!,
                                      Colors.orange[100]!
                                          .withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding:
                                      const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.shopping_cart_outlined,
                                        color: Colors.orange[700],
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Minimum Order for Redemption',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.bold,
                                              color:
                                              Colors.orange[900],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (walletPoints == 0)
                                                ? 'You have 0 points'
                                                : 'Add ₹${(2000 - totalAmount).toStringAsFixed(0)} more to redeem your ${walletPoints} points',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                              Colors.orange[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[600],
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '₹2000',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                                : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey
                                                .withOpacity(0.06),
                                            blurRadius: 6,
                                            offset:
                                            const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Available Points',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          isWalletLoading
                                              ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                              : Text(
                                            '${walletPoints}',
                                            style:
                                            const TextStyle(
                                              fontSize: 18,
                                              fontWeight:
                                              FontWeight
                                                  .bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: cartItems.isEmpty ||
                                          _isRedeeming
                                          ? null
                                          : () => _redeemNow(),
                                      icon: _isRedeeming
                                          ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                          AlwaysStoppedAnimation<
                                              Color>(
                                              Colors.white),
                                        ),
                                      )
                                          : const Icon(
                                        Icons.card_giftcard,
                                        size: 20,
                                      ),
                                      label: Text(
                                        _isRedeeming
                                            ? 'Redeeming...'
                                            : 'Redeem',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(
                                              12),
                                        ),
                                        padding: const EdgeInsets
                                            .symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (cartItems.isNotEmpty)
                            ApplyCouponWidget(
                              appliedCoupon: selectedCoupon,
                              onApply: _onCouponApplied,
                              currentCartTotal: totalAmount,
                              cartItems: cartItems,
                            ),
                          if (cartItems.isNotEmpty)
                            BillingDetailsWidget(
                              totalAmount: totalAmount,
                              deliveryFee: deliveryFee,
                              handlingFee: handlingFee,
                              deliveryFeeName: deliveryFeeName,
                              handlingFeeName: handlingFeeName,
                              selectedTip: selectedTip,
                              selectedDonation: selectedDonation,
                              grandTotal: grandTotal,
                              isFreeDelivery: isFreeDelivery,
                              thresholdMessage: thresholdMessage,
                              thresholdAmount: thresholdAmount,
                              discountAmount: _lastDiscountAmount ?? 0,
                              couponDiscount: couponDiscountAmount,
                            ),
                          if (cartItems.isNotEmpty)
                            _buildDeliveryOptionsSection(),
                          if (cartItems.isNotEmpty &&
                              showSlotSelection &&
                              !isInstantDelivery)
                            _buildDeliverySlotSection(),
                          if (cartItems.isNotEmpty)
                            PopularProductsWidget(
                              cartItems: cartItems,
                              onCartUpdated: () {
                                loadCart();
                              },
                            ),
                          if (cartItems.isNotEmpty)
                            CartOptionsWidgets(
                              selectedTipAmount: selectedTipAmount,
                              selectedDonationAmount: selectedDonationAmount,
                              onUpdateTip: updateTip,
                              onUpdateDonation: updateDonation,
                              onShowCustomTipDialog: _showCustomTipDialog,
                            ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (cartItems.isNotEmpty) _buildCheckoutButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySlotSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 20, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text(
                'Select Delivery Slot',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isLoadingSlots)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoadingSlots)
            Container(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Loading available slots...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else if (slotsByDate.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No delivery slots available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please try again later or contact support',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: loadDeliverySlots,
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('Refresh'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            isInstantDelivery = true;
                            showSlotSelection = false;
                            selectedSlotId = null;
                            selectedSlotData = null;
                          });
                        },
                        icon: Icon(Icons.flash_on, size: 18),
                        label: Text('Use Instant'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedSlotData != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: ${selectedSlotData!['displayText']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: slotsByDate.keys.map((dateKey) {
                      final bool isDateSelected = _selectedDateKey == dateKey;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(dateKey),
                          labelStyle: TextStyle(
                            color: isDateSelected
                                ? Colors.white
                                : Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                          selected: isDateSelected,
                          selectedColor: Colors.green.shade600,
                          backgroundColor: Colors.green.shade50,
                          onSelected: (isSelected) {
                            if (isSelected) {
                              setState(() {
                                _selectedDateKey = dateKey;
                              });
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDateSelected
                                  ? Colors.green.shade600
                                  : Colors.green.shade200,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedDateKey != null &&
                    slotsByDate[_selectedDateKey!] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slotsByDate[_selectedDateKey!]!.map((slot) {
                      final bool isBookable = slot['isAvailable'] == true;
                      final bool isSelected = selectedSlotId == slot['id'];
                      final String timeRange = slot['timeRange'] ?? 'N/A';

                      return GestureDetector(
                        onTap: () {
                          if (isBookable) {
                            selectDeliverySlot(slot);
                          } else {
                            _showErrorMessage(
                              "Delivery for these slots are full",
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.shade600
                                : (isBookable
                                ? Colors.white
                                : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.green.shade600
                                  : (isBookable
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            timeRange,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isBookable
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade500),
                              decoration: isBookable
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    'No slots available for $_selectedDateKey',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Please Login',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Login to view your cart and place orders',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login').then((_) {
                checkAuthAndLoadCart();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add some items to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              NavigationService.goBackToHomeScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 100, color: Colors.red.shade400),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Unknown error occurred',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                errorMessage = null;
              });
              checkAuthAndLoadCart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, size: 20, color: Colors.brown),
              const SizedBox(width: 8),
              const Text(
                'Your Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.brown.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cartItems.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.brown.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _buildCartItem(item);
            },
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey.shade200, height: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    final isFirstItem = cartItems.isNotEmpty && cartItems.first.id == item.id;
    final shouldShowHint = isFirstItem && _isShowingHint;

    final bool isOutOfStock = _outOfStockItemIds.contains(
      item.itemId,
    );

    return Stack(
      children: [
        if (shouldShowHint)
          Positioned.fill(
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          transform:
          Matrix4.identity()..translate(shouldShowHint ? -100.0 : 0.0, 0.0),
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.endToStart,
            dismissThresholds: const {DismissDirection.endToStart: 0.6},
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              return await _showRemoveConfirmationDialog(item);
            },
            onDismissed: (direction) {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.brown.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildProductImage(item),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${item.salesPrice.toStringAsFixed(0)} per item',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.brown.shade800,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '₹${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () => updateQuantity(
                                    item,
                                    item.quantity - 1,
                                  ),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isLoading
                                          ? Colors.grey.shade300
                                          : Colors.brown.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isLoading
                                            ? Colors.grey.shade400
                                            : Colors.brown.shade300,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      color: isLoading
                                          ? Colors.grey.shade600
                                          : Colors.brown.shade700,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  height: 32,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.quantity.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () => updateQuantity(
                                    item,
                                    item.quantity + 1,
                                  ),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isLoading
                                          ? Colors.grey.shade300
                                          : Colors.brown.shade800,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _showRemoveConfirmationDialog(CartItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove Item?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
                children: [
                  const TextSpan(text: 'Remove '),
                  TextSpan(
                    text: '"${item.itemName}"',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' from your cart?'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _buildProductImage(item, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Qty: ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.totalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Keep Item',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              removeItem(item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.itemName} removed from cart',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Remove',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    ) ??
        false;

    return false;
  }

  Widget _buildDeliveryOptionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildDeliveryOption(
              'Instant Delivery',
              'Charges applicable',
              Icons.delivery_dining,
              Colors.green,
              isInstantDelivery,
                  () => updateDeliveryType(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDeliveryOption(
              'Slot Delivery',
              'Book your own slot',
              Icons.schedule,
              Colors.green,
              !isInstantDelivery,
                  () => updateDeliveryType(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      bool isSelected,
      VoidCallback onTap,
      ) {
    bool isComingSoon = title == 'Instant Delivery';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.1)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? color : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                if (isComingSoon)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: isLoading || _isPreparingCheckout
                ? null
                : () => _prepareAndShowCheckoutPopup(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade800,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: isLoading || _isPreparingCheckout
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Checkout (₹${(grandTotal - (_lastDiscountAmount ?? 0)).toStringAsFixed(2)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.brown, strokeWidth: 3),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(CartItem item, {double size = 50}) {
    String imageUrl = '';

    if (item.itemImage.isNotEmpty) {
      imageUrl = item.itemImage;
    }

    if (imageUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SizedBox(
                    width: size * 0.3,
                    height: size * 0.3,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.brown.shade600,
                      ),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialsContainer(item.itemName, size);
            },
          ),
        ),
      );
    } else {
      return _buildInitialsContainer(item.itemName, size);
    }
  }

  Widget _buildInitialsContainer(String itemName, double size) {
    List<String> words = itemName.trim().split(' ');
    String initials;

    if (words.length >= 2) {
      initials = '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      String firstWord = words[0];
      initials = firstWord.length >= 2
          ? '${firstWord[0]}${firstWord[1]}'.toUpperCase()
          : firstWord[0].toUpperCase();
    } else {
      initials = '?';
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown.shade600, Colors.brown.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.3,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  void _showCustomTipDialog() {
    TextEditingController customTipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Custom Tip Amount'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customTipController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter tip amount',
                prefixText: '₹',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your delivery partner will appreciate your kindness!',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              double customAmount =
                  double.tryParse(customTipController.text) ?? 0.0;
              if (customAmount > 0) {
                updateTip(
                  '₹${customAmount.toStringAsFixed(0)}',
                  customAmount,
                );
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Tip'),
          ),
        ],
      ),
    );
  }
}