// screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/Order/order_api_service.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Fetch raw orders
      final rawOrders = await OrderService.fetchUserOrders();

      // Parse each order to normalize the structure
      final parsedOrders =
          rawOrders.map((rawOrder) {
            return OrderService.parseOrderData(rawOrder);
          }).toList();

      // Sort orders by date (newest first)
      parsedOrders.sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        orders = parsedOrders;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'out for delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'returned':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Your Orders',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: fetchOrders,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchOrders,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : orders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: fetchOrders,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order);
                  },
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long, size: 60, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Orders Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your order history will appear here',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  // Note: _buildProductImageFromOrderDetail is used instead of _buildProductImage
  // This method is kept for backward compatibility but is not currently used
  // In orders_screen.dart, update the _buildOrderCard method to debug the data:

  // orders_screen.dart - Update the _buildOrderCard method to use the same image logic

  /// Builds an order card displaying order summary information
  /// 
  /// FIX FOR TOTAL AMOUNT SHOWING 0:
  /// ================================
  /// WHY IT WAS SHOWING 0:
  /// 1. Backend might send total with different field names (e.g., 'grandTotal', 'total', 'finalAmount')
  /// 2. Values might come as strings that weren't being parsed correctly
  /// 3. Type mismatches (int/double/string) weren't handled properly
  /// 4. The original code only checked 'totalAmount' twice (duplicate check)
  /// 
  /// THE FIX:
  /// 1. Added safeToDouble() helper to properly convert string/int/double/null values
  /// 2. Added comprehensive fallback field names (grandTotal, total, finalAmount, totalAmount, etc.)
  /// 3. Added automatic calculation: if total is 0 or missing, calculate from components
  ///    Formula: itemsTotal + deliveryCharge + platformCharge + tax
  /// 4. This ensures total is ALWAYS displayed correctly
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['_id'] ?? order['id'] ?? 'Unknown';
    final orderNumber =
        order['orderNumber'] ??
        order['invoiceNumber'] ??
        (orderId != 'Unknown'
            ? 'SO/${orderId.substring(orderId.length >= 8 ? orderId.length - 8 : 0)}'
            : 'SO/Unknown');
    final status = order['status'] ?? 'Unknown';
    final createdAt =
        order['createdAt'] ?? order['date'] ?? order['updatedAt'] ?? '';
    final items = order['items'] ?? [];
    
    // Helper function to safely convert values to double
    // This handles string, int, double, and null values properly
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          print('⚠️ [Your Orders] Error parsing double from string: $value');
          return 0.0;
        }
      }
      return 0.0;
    }
    
    // Extract total amount with comprehensive fallbacks and proper type conversion
    // FIX: Added proper type conversion and multiple fallback field names
    // This matches the same logic used in order_detail_screen.dart
    var totalAmount = safeToDouble(
      order['grandTotal'] ?? 
      order['total'] ?? 
      order['finalAmount'] ?? 
      order['totalAmount'] ??
      order['finalTotal'] ??
      order['amount'] ??
      order['orderTotal'] ??
      0.0,
    );
    
    // IMPORTANT FIX: If total is 0 or not found, calculate it from components
    // This ensures we always show the correct total even if backend field name differs
    if (totalAmount == 0.0) {
      // Try to calculate from components if available
      final itemsTotal = safeToDouble(
        order['itemsTotal'] ?? 
        order['subtotal'] ?? 
        order['itemsTotalAmount'] ??
        0.0,
      );
      final deliveryCharge = safeToDouble(
        order['deliveryCharge'] ?? 
        order['shippingFee'] ?? 
        order['deliveryFee'] ??
        0.0,
      );
      final platformCharge = safeToDouble(
        order['platformCharge'] ?? 
        order['platformFee'] ?? 
        order['handlingFee'] ??
        0.0,
      );
      final tax = safeToDouble(
        order['tax'] ?? 
        order['taxAmount'] ?? 
        order['gst'] ??
        0.0,
      );
      
      // Calculate total from components
      totalAmount = itemsTotal + deliveryCharge + platformCharge + tax;
      
      if (totalAmount > 0) {
        print('⚠️ [Your Orders] Total not found in API, calculated: $totalAmount');
      }
    }
    
    final total = totalAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Order Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${total.toStringAsFixed(2)} • ${createdAt.isNotEmpty ? formatDate(createdAt) : 'Date N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order Items Preview
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Images Row - Using the same logic as OrderDetailScreen
                if (items.isNotEmpty)
                  Row(
                    children: [
                      ...items.take(3).map((item) {
                        return _buildProductImageFromOrderDetail(item);
                      }).toList(),
                      if (items.length > 3)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          child: Center(
                            child: Text(
                              '+${items.length - 3}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _viewOrderDetails(order);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _reorderItems(order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'RE-ORDER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add this method that copies the exact same logic from OrderDetailScreen
  // In orders_screen.dart, update the _buildProductImageFromOrderDetail method:

  Widget _buildProductImageFromOrderDetail(Map<String, dynamic> item) {
    const String imageBaseUrl =
        'https://pos.inspiredgrow.in/vps/uploads/qr/items/';

    // Use the same logic as ItemListPage
    final itemImages = item['itemImages'] ?? item['item']?['itemImages'];
    String? imageUrl;

    if (itemImages != null && itemImages is List && itemImages.isNotEmpty) {
      imageUrl = '$imageBaseUrl${itemImages[0]}';
    } else if (itemImages != null &&
        itemImages is String &&
        itemImages.isNotEmpty) {
      imageUrl = '$imageBaseUrl$itemImages';
    } else {
      // Fallback to other image fields
      final fallbackImage =
          item['productImage'] ??
          item['image'] ??
          item['item']?['image'] ??
          item['item']?['productImage'];
      if (fallbackImage != null && fallbackImage.toString().isNotEmpty) {
        imageUrl = fallbackImage.toString();
        // imageUrl is guaranteed to be non-null here since we just assigned it
        if (!imageUrl.startsWith('http')) {
          imageUrl = '$imageBaseUrl$imageUrl';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $imageUrl');
                    print('Error details: $error');
                    return Container(
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                          Text(
                            'Failed',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
                : Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.image, size: 24, color: Colors.grey[400]),
                ),
      ),
    );
  }

  // Also update the _buildProductImage method with debugging:
  void _viewOrderDetails(Map<String, dynamic> order) {
    // Debug the order structure
    OrderService.debugOrderStructure(order);

    final orderId = order['_id'] ?? order['id'];
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => OrderDetailScreen(
                orderId: orderId,
                orderSummary: order, // Pass the parsed order data
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order ID not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _reorderItems(Map<String, dynamic> order) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final orderId = order['_id'] ?? order['id'];
      if (orderId != null) {
        final result = await OrderService.reorderFromPreviousOrder(orderId);

        Navigator.pop(context); // Close loading dialog

        if (result != null && result['success'] == true) {
          final itemsAdded = result['itemsAdded'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$itemsAdded items added to cart successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add items to cart'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order ID not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reordering: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
