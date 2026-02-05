import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';
import '../Cart/cart_service.dart';
import '../Notification/order_notification_manager.dart';
import '../warehouse/warehouse_service.dart';

class OrderService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps';
  static final UserData _userData = UserData();
  static final OrderNotificationManager _notificationManager =
  OrderNotificationManager();

  static Map<String, String> _getHeaders() {
    final token = _userData.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Helper to extract date from MongoDB Extended JSON format { "$date": "..." }
  static String _extractDateString(dynamic dateVal) {
    if (dateVal == null) return '';

    // If it's already a string (e.g. "2026-01-01..."), just return it
    if (dateVal is String) return dateVal;

    // If it's a Map (e.g. { "$date": "..." }), extract the inner string
    if (dateVal is Map) {
      if (dateVal.containsKey('\$date')) {
        return dateVal['\$date']?.toString() ?? '';
      }
      // Handle rare case of { "date": "..." }
      if (dateVal.containsKey('date')) {
        return dateVal['date']?.toString() ?? '';
      }
    }

    return dateVal.toString();
  }

  static Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String phoneNumber,
    required String email,
    required String houseNo,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    required String locationLink,
    String? deliverySlotId,
    Map<String, dynamic>? deliverySlotInfo,
    bool isInstantDelivery = false,
    String? assignTo,
    String? warehouseId,
    required double subtotal,
    required double deliveryCharge,
    required double processingFee,
    required double tip,
    required double donation,
    required double totalAmount,
    required String paymentMethod,
    required String paymentStatus,
    required double tax,
    required double discountApplied,
    String? couponCode,
    double couponDiscount = 0.0,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      if (warehouseId == null) {
        final userData = UserData();
        final user = userData.getCurrentUser();
        warehouseId = user?.selectedWarehouseId;
        print(' Using user\'s assigned warehouse: $warehouseId');
      } else {
        print(' Using provided warehouse: $warehouseId');
      }

      if (warehouseId == null || warehouseId.isEmpty) {
        throw Exception(
          'Warehouse ID is required. Please check your delivery location.',
        );
      }

      if (!isInstantDelivery && deliverySlotId != null) {
        print('Selected Delivery Slot ID: $deliverySlotId');
        print('Delivery Slot Info: $deliverySlotInfo');
      }

      final checkoutSession = await createCheckoutSession();

      if (checkoutSession == null) {
        throw Exception('Failed to create checkout session');
      }

      final checkoutSessionId =
          checkoutSession['data']?['checkoutSessionId']?.toString() ??
              checkoutSession['checkoutSessionId']?.toString() ??
              checkoutSession['sessionId']?.toString() ??
              checkoutSession['id']?.toString();

      if (checkoutSessionId == null) {
        print(' Checkout session structure: ${checkoutSession.keys}');
        if (checkoutSession['data'] != null) {
          print(' Data structure: ${checkoutSession['data'].keys}');
        }
        throw Exception('No checkout session ID returned');
      }

      print(' Using checkout session ID: $checkoutSessionId');

      final orderResult = await placeOrderFromSession(
        checkoutSessionId: checkoutSessionId,
        customerName: customerName,
        phoneNumber: phoneNumber,
        email: email,
        houseNo: houseNo,
        area: area,
        city: city,
        state: state,
        postalCode: postalCode,
        locationLink: locationLink,
        assignTo: assignTo,
        deliverySlotId: deliverySlotId,
        deliverySlotInfo: deliverySlotInfo,
        isInstantDelivery: isInstantDelivery,
        warehouseId: warehouseId,
        subtotal: subtotal,
        deliveryCharge: deliveryCharge,
        processingFee: processingFee,
        tip: tip,
        donation: donation,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        tax: tax,
        discountApplied: discountApplied,
        couponCode: couponCode,
        couponDiscount: couponDiscount,
        razorpayPaymentId: razorpayPaymentId,
        razorpayOrderId: razorpayOrderId,
        razorpaySignature: razorpaySignature,
      );

      await _handleOrderPlacedNotification(orderResult, checkoutSession);

      return orderResult;
    } catch (e) {
      print('=== ORDER CREATION FAILED ===');
      print('Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> placeOrderFromSession({
    required String checkoutSessionId,
    required String customerName,
    required String phoneNumber,
    required String email,
    required String houseNo,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    required String locationLink,
    String? assignTo,
    String? deliverySlotId,
    Map<String, dynamic>? deliverySlotInfo,
    bool isInstantDelivery = false,
    required String warehouseId,
    required double subtotal,
    required double deliveryCharge,
    required double processingFee,
    required double tip,
    required double donation,
    required double totalAmount,
    required String paymentMethod,
    required String paymentStatus,
    required double tax,
    required double discountApplied,
    String? couponCode,
    double couponDiscount = 0.0,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      print('=== PLACING ORDER FROM SESSION (CREATING ACTUAL ORDER) ===');
      print(' Order Financial Details:');
      print('   Total Amount: ₹$totalAmount');
      print('   Coupon Code: $couponCode');
      print('   Coupon Discount: ₹$couponDiscount');
      print(' Store/Warehouse ID: $warehouseId');

      final orderData = {
        'checkoutSessionId': checkoutSessionId,
        'customerName': customerName,
        'phoneNumber': phoneNumber,
        'email': email,
        'country': 'India',
        'state': state,
        'city': city,
        'houseNo': houseNo,
        'area': area,
        'postalCode': postalCode,
        'locationLink': locationLink,
        if (assignTo != null) 'assignTo': assignTo,
        'store': warehouseId,
        'subtotal': subtotal,
        'deliveryCharge': deliveryCharge,
        'processingFee': processingFee,
        'tip': tip,
        'donation': donation,
        'totalAmount': totalAmount,
        'grandTotal': totalAmount,
        'tax': tax,
        'discountApplied': discountApplied,
        if (couponCode != null && couponCode.isNotEmpty)
          'couponCode': couponCode,
        'couponDiscount': couponDiscount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
        if (razorpaySignature != null) 'razorpaySignature': razorpaySignature,
        'deliveryType': isInstantDelivery ? 'instant' : 'scheduled',
        'isInstantDelivery': isInstantDelivery,
        if (deliverySlotId != null) 'deliverySlotId': deliverySlotId,
        if (deliverySlotInfo != null) 'deliverySlotInfo': deliverySlotInfo,
        if (!isInstantDelivery && deliverySlotInfo != null) ...{
          'scheduledDeliveryDate': deliverySlotInfo['date'],
          'scheduledDeliveryTime':
          deliverySlotInfo['timeRange'] ?? deliverySlotInfo['startTime'],
          'deliverySlotDetails': {
            'slotId': deliverySlotId,
            'date': deliverySlotInfo['date'],
            'startTime': deliverySlotInfo['startTime'],
            'endTime': deliverySlotInfo['endTime'],
            'displayText': deliverySlotInfo['displayText'],
          },
        },
      };

      print(' Request Body (with "store" field):');
      print(jsonEncode(orderData));

      final response = await http
          .post(
        Uri.parse('$baseUrl/api/orders/place-from-session'),
        headers: _getHeaders(),
        body: jsonEncode(orderData),
      )
          .timeout(const Duration(seconds: 30));

      print('📥 Order placement response: ${response.statusCode}');
      print('📥 Order placement body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['success'] == false) {
          String failureReason =
              data['error'] ?? data['message'] ?? 'Unknown error occurred';
          print(' Order placement logic failure: $failureReason');
          throw Exception(failureReason);
        }

        print(' ORDER CREATED SUCCESSFULLY!');

        if (paymentMethod.toUpperCase() != 'COD') {
          final orderResult = data['data'] ?? data['order'] ?? data;
          final orderId =
              orderResult['_id']?.toString() ?? orderResult['id']?.toString();

          if (orderId != null) {
            await sendPaymentConfirmation(
              orderId: orderId,
              amount: totalAmount,
              paymentMethod: paymentMethod,
            );
          }
        }

        return Map<String, dynamic>.from(data as Map);
      } else {
        String errorMessage = 'Order creation failed: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['error'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = response.body;
        }

        print(' Order creation error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(' Error creating order from session: $e');
      rethrow;
    }
  }

  static Future<void> _handleOrderPlacedNotification(
      Map<String, dynamic> orderResult,
      Map<String, dynamic> checkoutSession,
      ) async {
    try {
      final customerId = _userData.getUserId();
      if (customerId == null) {
        print('No customer ID found for notification');
        return;
      }

      final orderData =
          orderResult['data'] ?? orderResult['order'] ?? orderResult;
      final orderId =
          orderData['_id']?.toString() ??
              orderData['id']?.toString() ??
              orderData['orderId']?.toString();

      if (orderId == null) {
        print('No order ID found for notification');
        return;
      }

      double totalAmount = 0.0;
      final finalAmount =
          orderData['finalAmount'] ??
              orderData['total'] ??
              orderData['grandTotal'] ??
              orderData['totalAmount'] ??
              checkoutSession['data']?['total'] ??
              checkoutSession['total'];

      if (finalAmount != null) {
        totalAmount = safeToDouble(finalAmount);
      }

      final items =
          checkoutSession['data']?['items'] ??
              checkoutSession['items'] ??
              orderData['items'] ??
              [];

      List<String> itemNames = [];
      if (items is List) {
        itemNames =
            items.map((item) {
              final itemMap = item as Map<String, dynamic>;
              final itemData = itemMap['item'];

              if (itemData is Map) {
                return itemData['itemName']?.toString() ??
                    itemData['productName']?.toString() ??
                    'Unknown Item';
              } else {
                return itemMap['itemName']?.toString() ??
                    itemMap['productName']?.toString() ??
                    'Product';
              }
            }).toList();
      }

      await _notificationManager.handleOrderPlaced(
        customerId: customerId,
        orderId: orderId,
        orderAmount: totalAmount,
        items: itemNames,
      );

      print(' Order placed notification sent successfully');
    } catch (e) {
      print('Error sending order placed notification: $e');
    }
  }

  static Future<bool> updateOrderStatus(
      String orderId,
      String status, {
        String? estimatedDeliveryTime,
        String? trackingNumber,
        String? customerId,
      }) async {
    try {
      print('=== UPDATING ORDER STATUS ===');
      print('Order ID: $orderId, New Status: $status');

      final requestBody = {
        'status': status,
        if (estimatedDeliveryTime != null)
          'estimatedDeliveryTime': estimatedDeliveryTime,
        if (trackingNumber != null) 'trackingNumber': trackingNumber,
      };

      final response = await http
          .put(
        Uri.parse('$baseUrl/api/orders/update-status/$orderId'),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 30));

      print('Update order status response: ${response.statusCode}');
      print('Update order status body: ${response.body}');

      if (response.statusCode == 200) {
        await _handleOrderStatusUpdateNotification(
          orderId: orderId,
          newStatus: status,
          customerId: customerId,
          estimatedDeliveryTime: estimatedDeliveryTime,
          trackingNumber: trackingNumber,
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  static Future<void> _handleOrderStatusUpdateNotification({
    required String orderId,
    required String newStatus,
    String? customerId,
    String? estimatedDeliveryTime,
    String? trackingNumber,
  }) async {
    try {
      final targetCustomerId = customerId ?? _userData.getUserId();

      if (targetCustomerId == null) {
        final orderDetails = await fetchOrderDetails(orderId);
        if (orderDetails != null) {
          final parsedOrder = parseOrderData(orderDetails);
          final customerData = parsedOrder['customer'] as Map<String, dynamic>?;
          final orderCustomerId =
              customerData?['_id']?.toString() ??
                  customerData?['id']?.toString();

          if (orderCustomerId != null) {
            await _notificationManager.handleOrderStatusChange(
              customerId: orderCustomerId,
              orderId: orderId,
              newStatus: newStatus,
              estimatedDeliveryTime: estimatedDeliveryTime,
              trackingNumber: trackingNumber,
            );
            print(' Order status update notification sent successfully');
            return;
          }
        }
        print('No customer ID found for status update notification');
        return;
      }

      await _notificationManager.handleOrderStatusChange(
        customerId: targetCustomerId,
        orderId: orderId,
        newStatus: newStatus,
        estimatedDeliveryTime: estimatedDeliveryTime,
        trackingNumber: trackingNumber,
      );

      print(' Order status update notification sent successfully');
    } catch (e) {
      print('Error sending order status update notification: $e');
    }
  }

  static Future<void> sendDeliveryReminder({
    required String orderId,
    required String estimatedTime,
    String? customerId,
  }) async {
    try {
      final targetCustomerId = customerId ?? _userData.getUserId();
      if (targetCustomerId == null) {
        print('No customer ID found for delivery reminder');
        return;
      }

      await _notificationManager.sendDeliveryReminder(
        customerId: targetCustomerId,
        orderId: orderId,
        estimatedTime: estimatedTime,
      );

      print(' Delivery reminder sent successfully');
    } catch (e) {
      print('Error sending delivery reminder: $e');
    }
  }

  static Future<void> sendPaymentConfirmation({
    required String orderId,
    required double amount,
    required String paymentMethod,
    String? customerId,
  }) async {
    try {
      final targetCustomerId = customerId ?? _userData.getUserId();
      if (targetCustomerId == null) {
        print('No customer ID found for payment confirmation');
        return;
      }

      await _notificationManager.sendPaymentConfirmation(
        customerId: targetCustomerId,
        orderId: orderId,
        amount: amount,
        paymentMethod: paymentMethod,
      );

      print(' Payment confirmation notification sent successfully');
    } catch (e) {
      print('Error sending payment confirmation: $e');
    }
  }

  static String? getCurrentStoreId() {
    final userData = UserData();
    final user = userData.getCurrentUser();
    return user?.selectedWarehouseId;
  }

  static Future<bool> validateStoreAssignment() async {
    final storeId = getCurrentStoreId();

    if (storeId == null || storeId.isEmpty) {
      print(' No store assigned to user');

      final userData = UserData();
      final token = userData.getToken();

      if (token != null) {
        try {
          final result = await ZoneWarehouseService.autoAssignWarehouse(token);
          return result.isServiceable;
        } catch (e) {
          print('❌ Failed to auto-assign store: $e');
          return false;
        }
      }

      return false;
    }

    print(' Store validated: $storeId');
    return true;
  }

  static Future<void> triggerTestNotification({
    required String orderId,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final customerId = _userData.getUserId();
      if (customerId == null) {
        print('No customer ID found for test notification');
        return;
      }

      switch (type) {
        case 'order_placed':
          await _notificationManager.handleOrderPlaced(
            customerId: customerId,
            orderId: orderId,
            orderAmount: additionalData?['amount'] ?? 100.0,
            items: additionalData?['items'] ?? ['Test Item'],
          );
          break;

        case 'status_change':
          await _notificationManager.handleOrderStatusChange(
            customerId: customerId,
            orderId: orderId,
            newStatus: additionalData?['status'] ?? 'processing',
            estimatedDeliveryTime: additionalData?['estimatedTime'],
          );
          break;

        case 'payment':
          await _notificationManager.sendPaymentConfirmation(
            customerId: customerId,
            orderId: orderId,
            amount: additionalData?['amount'] ?? 100.0,
            paymentMethod: additionalData?['paymentMethod'] ?? 'UPI',
          );
          break;

        case 'delivery_reminder':
          await _notificationManager.sendDeliveryReminder(
            customerId: customerId,
            orderId: orderId,
            estimatedTime: additionalData?['estimatedTime'] ?? '30 minutes',
          );
          break;
      }

      print(' Test notification sent successfully');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  static Future<Map<String, dynamic>?> fetchItemDetails(String itemId) async {
    try {
      print('=== FETCHING ITEM DETAILS: $itemId ===');

      final response = await http
          .get(
        Uri.parse('$baseUrl/customer/items/$itemId'),
        headers: _getHeaders(),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data as Map);
      } else {
        print('Failed to fetch item details: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching item details: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUserOrders() async {
    try {
      print('=== FETCHING USER ORDERS ===');

      final response = await http
          .get(Uri.parse('$baseUrl/api/orders'), headers: _getHeaders())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message']?.toString() ?? '';

        if (errorMessage.contains('deliveryAgent') ||
            errorMessage.contains('strictPopulate')) {
          print(
            '️ Backend schema error detected - deliveryAgent populate issue',
          );
          throw Exception(
            'Server configuration error: The delivery agent field is not properly configured. '
                'Please contact support or try again later.',
          );
        }

        throw Exception(
          'Server error: ${errorMessage.isNotEmpty ? errorMessage : response.body}',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<Map<String, dynamic>> ordersList = [];

        if (data is List) {
          ordersList =
              data
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
        } else if (data is Map) {
          final possibleKeys = ['data', 'orders', 'results', 'items'];
          for (final key in possibleKeys) {
            if (data[key] is List) {
              final list = data[key] as List;
              ordersList =
                  list
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .toList();
              break;
            }
          }
          if (ordersList.isEmpty && data.containsKey('_id')) {
            ordersList = [Map<String, dynamic>.from(data)];
          }
        }

        print('Orders list length: ${ordersList.length}');
        return ordersList;
      } else {
        throw Exception(
          'Failed to fetch orders: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching user orders: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> fetchOrderDetails(String orderId) async {
    try {
      print('=== FETCHING ORDER DETAILS: $orderId ===');

      final response = await http
          .get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: _getHeaders(),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map) {
          final orderData = data['data'] ?? data;
          return Map<String, dynamic>.from(orderData as Map);
        }

        return Map<String, dynamic>.from(data as Map);
      } else {
        print(
          'Failed to fetch order details: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error fetching order details: $e');
      return null;
    }
  }

  static String getOrderNumberFromId(String orderId) {
    try {
      if (orderId.length >= 8) {
        return 'SO/${orderId.substring(orderId.length - 8)}';
      } else {
        return 'SO/$orderId';
      }
    } catch (e) {
      print('Error creating order number from ID: $e');
      return 'SO/Unknown';
    }
  }

  static double safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print('Error parsing double from string: $value');
        return 0.0;
      }
    }
    return 0.0;
  }

  static int safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        print('Error parsing int from string: $value');
        return 0;
      }
    }
    return 0;
  }

  static Map<String, dynamic> parseOrderData(Map<String, dynamic> rawOrder) {
    try {
      final orderId =
          rawOrder['_id']?.toString() ??
              rawOrder['id']?.toString() ??
              rawOrder['orderId']?.toString();

      final orderNumber =
          rawOrder['orderNumber']?.toString() ??
              rawOrder['invoiceNumber']?.toString() ??
              (orderId != null ? getOrderNumberFromId(orderId) : 'SO/Unknown');

      final customerData =
          rawOrder['customer'] ?? rawOrder['customerDetails'] ?? {};
      final customer =
      customerData is Map
          ? Map<String, dynamic>.from(customerData)
          : <String, dynamic>{};

      final customerName =
          customer['name']?.toString() ??
              rawOrder['customerName']?.toString() ??
              'N/A';
      final customerPhone =
          customer['phone']?.toString() ??
              rawOrder['customerPhone']?.toString() ??
              rawOrder['phoneNumber']?.toString() ??
              'N/A';
      final customerEmail =
          customer['email']?.toString() ??
              rawOrder['customerEmail']?.toString() ??
              'N/A';

      final shippingAddressData =
          rawOrder['shippingAddress'] ??
              rawOrder['deliveryAddress'] ??
              rawOrder['address'];
      Map<String, dynamic> shippingAddress = {};

      if (shippingAddressData is List && shippingAddressData.isNotEmpty) {
        shippingAddress = Map<String, dynamic>.from(
          shippingAddressData[0] as Map,
        );
      } else if (shippingAddressData is Map) {
        shippingAddress = Map<String, dynamic>.from(shippingAddressData);
      }

      final rawItems =
          rawOrder['items'] ??
              rawOrder['orderItems'] ??
              rawOrder['products'] ??
              [];
      List<Map<String, dynamic>> parsedItems = [];

      if (rawItems is List) {
        parsedItems =
            rawItems.map((item) {
              try {
                final itemMap = Map<String, dynamic>.from(item as Map);

                final itemData =
                    itemMap['item'] ?? itemMap['product'] ?? itemMap;
                final itemDataMap =
                itemData is Map
                    ? Map<String, dynamic>.from(itemData)
                    : <String, dynamic>{};

                final brandData = itemDataMap['brand'] ?? {};
                final brandMap =
                brandData is Map
                    ? Map<String, dynamic>.from(brandData)
                    : <String, dynamic>{};

                final categoryData = itemDataMap['category'] ?? {};
                final categoryMap =
                categoryData is Map
                    ? Map<String, dynamic>.from(categoryData)
                    : <String, dynamic>{};

                String? imageUrl = _extractImageUrl(itemDataMap);

                return {
                  'productName':
                  itemDataMap['itemName']?.toString() ??
                      itemDataMap['productName']?.toString() ??
                      itemDataMap['name']?.toString() ??
                      'Unknown Product',
                  'itemName':
                  itemDataMap['itemName']?.toString() ??
                      itemDataMap['productName']?.toString() ??
                      itemDataMap['name']?.toString() ??
                      'Unknown Product',
                  'quantity': safeToInt(
                    itemMap['quantity'] ?? itemMap['qty'] ?? 1,
                  ),
                  'price': safeToDouble(
                    itemMap['price'] ??
                        itemMap['salesPrice'] ??
                        itemMap['unitPrice'],
                  ),
                  'salesPrice': safeToDouble(
                    itemMap['salesPrice'] ??
                        itemMap['price'] ??
                        itemMap['unitPrice'],
                  ),
                  'productImage': imageUrl,
                  'image': imageUrl,
                  'brand':
                  brandMap['brandName']?.toString() ??
                      brandMap['name']?.toString() ??
                      '',
                  'category':
                  categoryMap['name']?.toString() ??
                      categoryMap['categoryName']?.toString() ??
                      '',
                  'item': itemDataMap,
                  'itemId':
                  itemDataMap['_id']?.toString() ??
                      itemDataMap['id']?.toString(),
                  'itemImages': itemDataMap['itemImages'],
                };
              } catch (e) {
                return {
                  'productName': 'Unknown Product',
                  'itemName': 'Unknown Product',
                  'quantity': 1,
                  'price': 0.0,
                  'salesPrice': 0.0,
                  'productImage': null,
                  'image': null,
                  'brand': '',
                  'category': '',
                  'item': <String, dynamic>{},
                  'itemId': null,
                  'itemImages': null,
                };
              }
            }).toList();
      }

      final finalAmount = safeToDouble(
        rawOrder['finalAmount'] ??
            rawOrder['total'] ??
            rawOrder['grandTotal'] ??
            rawOrder['totalAmount'],
      );
      final tax = safeToDouble(
        rawOrder['tax'] ??
            rawOrder['taxAmount'] ??
            rawOrder['gst'] ??
            rawOrder['vat'],
      );

      final deliveryCharge = safeToDouble(
        rawOrder['deliveryCharge'] ?? rawOrder['deliveryFee'],
      );

      final processingFee = safeToDouble(
        rawOrder['processingFee'] ?? rawOrder['paymentProcessingFee'],
      );

      final platformCharge = safeToDouble(
        rawOrder['platformCharge'] ??
            rawOrder['platformFee'] ??
            rawOrder['handlingFee'],
      );

      final discountApplied = safeToDouble(
        rawOrder['discountApplied'] ??
            rawOrder['discount'] ??
            rawOrder['discountAmount'],
      );

      final tip = safeToDouble(rawOrder['tip']);
      final donation = safeToDouble(rawOrder['donation']);

      final couponCode = rawOrder['couponCode']?.toString();
      final couponId = rawOrder['coupon']?.toString();
      double couponDiscount = safeToDouble(rawOrder['couponDiscount']);

      if (couponDiscount == 0.0 && discountApplied > 0) {
        couponDiscount = discountApplied;
      }

      double itemsTotal = 0.0;

      try {
        itemsTotal = parsedItems.fold(
          0.0,
              (sum, item) =>
          sum + (safeToDouble(item['price']) * safeToInt(item['quantity'])),
        );
      } catch (e) {
        itemsTotal = finalAmount;
      }

      // === FIXED DATE PARSING ===
      // Use helper method to extract string from potential { $date: ... } map
      final createdAtRaw =
          rawOrder['createdAt'] ??
              rawOrder['orderDate'] ??
              rawOrder['orderTime'];
      final updatedAtRaw = rawOrder['updatedAt'] ?? rawOrder['lastUpdated'];

      return {
        '_id': orderId ?? 'Unknown',
        'id': orderId ?? 'Unknown',
        'orderNumber': orderNumber,
        'invoiceNumber': orderNumber,
        'status': rawOrder['status']?.toString() ?? 'Unknown',
        'createdAt': _extractDateString(createdAtRaw),
        'updatedAt': _extractDateString(updatedAtRaw),
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'customer': customer,
        'country':
        shippingAddress['country']?.toString() ??
            rawOrder['country']?.toString() ??
            '',
        'state':
        shippingAddress['state']?.toString() ??
            rawOrder['state']?.toString() ??
            '',
        'city':
        shippingAddress['city']?.toString() ??
            rawOrder['city']?.toString() ??
            '',
        'houseNo':
        shippingAddress['houseNo']?.toString() ??
            rawOrder['houseNo']?.toString() ??
            '',
        'area':
        shippingAddress['area']?.toString() ??
            rawOrder['area']?.toString() ??
            '',
        'postalCode':
        shippingAddress['postalCode']?.toString() ??
            rawOrder['postalCode']?.toString() ??
            '',
        'locationLink':
        shippingAddress['locationLink']?.toString() ??
            rawOrder['locationLink']?.toString() ??
            '',
        'shippingAddress': shippingAddress,
        'paymentMethod': rawOrder['paymentMethod']?.toString() ?? 'N/A',
        'paymentStatus': rawOrder['paymentStatus']?.toString() ?? 'N/A',
        'items': parsedItems,
        'itemsTotal': itemsTotal,
        'subtotal': itemsTotal,
        'tax': tax,
        'deliveryCharge': deliveryCharge,
        'processingFee': processingFee,
        'platformCharge': platformCharge,
        'discountApplied': discountApplied,
        'tip': tip,
        'donation': donation,
        'couponCode': couponCode,
        'couponId': couponId,
        'couponDiscount': couponDiscount,
        'finalAmount': finalAmount,
        'grandTotal': finalAmount,
        'total': finalAmount,
        'totalAmount': finalAmount,
        'deliveryType':
        rawOrder['deliveryType']?.toString() ??
            (rawOrder['isInstantDelivery'] == true ? 'instant' : 'scheduled'),
        'isInstantDelivery': rawOrder['isInstantDelivery'] ?? false,
        'deliverySlotId': rawOrder['deliverySlotId']?.toString(),
        'deliverySlotInfo': rawOrder['deliverySlotInfo'],
        'scheduledDeliveryDate': rawOrder['scheduledDeliveryDate']?.toString(),
        'scheduledDeliveryTime': rawOrder['scheduledDeliveryTime']?.toString(),
        'deliverySlotDetails': rawOrder['deliverySlotDetails'],
      };
    } catch (e) {
      return {
        '_id': 'Unknown',
        'id': 'Unknown',
        'orderNumber': 'SO/Unknown',
        'invoiceNumber': 'SO/Unknown',
        'status': 'Unknown',
        'createdAt': '',
        'updatedAt': '',
        'customerName': 'N/A',
        'customerPhone': 'N/A',
        'customerEmail': 'N/A',
        'customer': <String, dynamic>{},
        'country': '',
        'state': '',
        'city': '',
        'houseNo': '',
        'area': '',
        'postalCode': '',
        'locationLink': '',
        'shippingAddress': <String, dynamic>{},
        'paymentMethod': 'N/A',
        'paymentStatus': 'N/A',
        'items': <Map<String, dynamic>>[],
        'itemsTotal': 0.0,
        'subtotal': 0.0,
        'tax': 0.0,
        'deliveryCharge': 0.0,
        'discountApplied': 0.0,
        'tip': 0.0,
        'donation': 0.0,
        'finalAmount': 0.0,
        'grandTotal': 0.0,
        'total': 0.0,
        'deliveryType': 'scheduled',
        'isInstantDelivery': false,
        'deliverySlotId': null,
        'deliverySlotInfo': null,
        'scheduledDeliveryDate': null,
        'scheduledDeliveryTime': null,
        'deliverySlotDetails': null,
      };
    }
  }

  static String? _extractImageUrl(Map<String, dynamic> itemData) {
    const String imageBaseUrl =
        'https://pos.inspiredgrow.in/vps/uploads/qr/items/';

    final itemImages = itemData['itemImages'];
    if (itemImages != null && itemImages is List && itemImages.isNotEmpty) {
      final firstImage = itemImages[0].toString();
      if (firstImage.isNotEmpty) {
        final imageUrl = '$imageBaseUrl$firstImage';
        return imageUrl;
      }
    }

    if (itemImages != null && itemImages is String && itemImages.isNotEmpty) {
      final imageUrl = '$imageBaseUrl$itemImages';
      return imageUrl;
    }

    final imageFields = [
      'image',
      'productImage',
      'imageUrl',
      'img',
      'picture',
      'photo',
      'thumbnail',
      'itemImage',
      'productImg',
      'images',
    ];

    for (final field in imageFields) {
      final value = itemData[field];
      if (value != null) {
        if (value is List && value.isNotEmpty) {
          final firstImage = value[0].toString();
          if (firstImage.isNotEmpty) {
            String imageUrl = firstImage;
            if (!imageUrl.startsWith('http')) {
              imageUrl = '$imageBaseUrl$imageUrl';
            }
            return imageUrl;
          }
        } else if (value is String && value.isNotEmpty) {
          String imageUrl = value;
          if (!imageUrl.startsWith('http')) {
            imageUrl = '$imageBaseUrl$imageUrl';
          }
          return imageUrl;
        }
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> reorderFromPreviousOrder(
      String orderId,
      ) async {
    try {
      print('=== REORDERING FROM ORDER: $orderId ===');

      final orderDetails = await fetchOrderDetails(orderId);
      if (orderDetails == null) {
        throw Exception('Could not fetch order details for reordering');
      }

      final parsedOrder = parseOrderData(orderDetails);

      final items = parsedOrder['items'] ?? [];
      if (items.isEmpty) {
        throw Exception('No items found in the order');
      }

      List<Map<String, dynamic>> cartItems = [];
      for (final item in items) {
        final itemId =
            item['itemId'] ?? item['_id'] ?? item['id'] ?? item['productId'];
        final quantity = item['quantity'] ?? 1;

        if (itemId != null) {
          cartItems.add({
            'itemId': itemId.toString(),
            'quantity':
            quantity is int
                ? quantity
                : int.tryParse(quantity.toString()) ?? 1,
          });
        }
      }

      if (cartItems.isEmpty) {
        throw Exception('No valid items found for reordering');
      }

      print('Adding ${cartItems.length} items to cart: $cartItems');

      final result = await CartService.addItemsToCart(items: cartItems);

      if (result != null) {
        if (result.containsKey('error')) {
          throw Exception(result['error']);
        }

        return {
          'success': true,
          'message': 'Items from order $orderId added to cart successfully',
          'itemsAdded': cartItems.length,
          'cartResult': result,
        };
      } else {
        throw Exception('Failed to add items to cart');
      }
    } catch (e) {
      print('Error reordering: $e');
      rethrow;
    }
  }

  static void debugOrderStructure(Map<String, dynamic> order) {
    print('=== ORDER STRUCTURE DEBUG ===');
    print('Order keys: ${order.keys.toList()}');
    print('Order ID: ${order['_id'] ?? order['id'] ?? 'NOT FOUND'}');
    print('Order Number: ${order['orderNumber'] ?? 'NOT FOUND'}');
    print('Status: ${order['status'] ?? 'NOT FOUND'}');

    if (order['items'] != null) {
      print('Items structure:');
      final items = order['items'];
      if (items is List) {
        print('Items count: ${items.length}');
        if (items.isNotEmpty) {
          print('First item keys: ${items[0].keys.toList()}');
          print(
            'First item sample: ${items[0].toString().substring(0, items[0].toString().length > 200 ? 200 : items[0].toString().length)}...',
          );
        }
      } else {
        print('Items is not a List: ${items.runtimeType}');
      }
    }

    print('Order data sample:');
    order.forEach((key, value) {
      if (value is List) {
        print('$key: List with ${value.length} items');
      } else if (value is Map) {
        print('$key: Map with keys ${value.keys.toList()}');
      } else {
        final valueStr = value.toString();
        print(
          '$key: ${valueStr.length > 100 ? valueStr.substring(0, 100) + '...' : valueStr}',
        );
      }
    });
    print('=== END DEBUG ===');
  }

  static Future<Map<String, dynamic>?> createCheckoutSession({
    String? warehouseId,
  }) async {
    try {
      print('=== CREATING CHECKOUT SESSION (FETCHING CART ITEMS) ===');

      if (warehouseId == null) {
        final userData = UserData();
        final user = userData.getCurrentUser();
        warehouseId = user?.selectedWarehouseId;
      }

      print(' Store/Warehouse ID for checkout: $warehouseId');

      final checkoutData = {
        if (warehouseId != null && warehouseId.isNotEmpty) 'store': warehouseId,
      };

      print('Creating checkout session with JWT token authentication');
      print(' Checkout session data: ${jsonEncode(checkoutData)}');

      final response = await http
          .post(
        Uri.parse('$baseUrl/api/orders/create-checkout-session'),
        headers: _getHeaders(),
        body: jsonEncode(checkoutData),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Checkout session created successfully');
        print('Cart items fetched using JWT token');
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception(
          'Failed to create checkout session: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error creating checkout session: $e');
      rethrow;
    }
  }
}
