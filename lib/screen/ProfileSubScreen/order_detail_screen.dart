// screens/order_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../services/Order/order_api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderSummary;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderSummary,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? orderDetails;
  bool isLoading = false;
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    orderDetails = widget.orderSummary;
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
        errorMessage = null;
      });

      print('🔍 [Order Details] Fetching details for order: ${widget.orderId}');

      final rawDetails = await OrderService.fetchOrderDetails(widget.orderId)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (rawDetails != null) {
        final parsedDetails = OrderService.parseOrderData(rawDetails);
        setState(() {
          orderDetails = parsedDetails;
          isLoading = false;
          hasError = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = false;
        });
      }
    } catch (e) {
      print('❌ [Order Details] Error: $e');
      setState(() {
        hasError = false;
        isLoading = false;
      });
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'processing': return Colors.purple;
      case 'shipped': return Colors.indigo;
      case 'out for delivery': return Colors.teal;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'returned': return Colors.grey;
      default: return Colors.grey;
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
    if (orderDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Summary'), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final order = orderDetails!;

    final orderId = order['_id'] ?? order['id'] ?? 'Unknown';
    final orderNumber = order['orderNumber'] ?? order['invoiceNumber'] ?? 'SO/${orderId.substring(orderId.length - 8)}';
    final status = order['status'] ?? 'Unknown';
    final createdAt = order['createdAt'] ?? order['date'] ?? '';
    final items = order['items'] ?? [];

    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final subtotal = safeToDouble(order['subtotal'] ?? order['itemsTotal'] ?? order['itemsTotalAmount'] ?? 0.0);
    final tax = safeToDouble(order['tax'] ?? order['taxAmount'] ?? order['gst'] ?? 0.0);
    final discountApplied = safeToDouble(order['discountApplied'] ?? order['discount'] ?? 0.0);
    final deliveryCharge = safeToDouble(order['deliveryCharge'] ?? order['deliveryFee'] ?? 0.0);
    final processingFee = safeToDouble(order['processingFee'] ?? order['paymentProcessingFee'] ?? 0.0);
    final platformCharge = safeToDouble(order['platformCharge'] ?? order['platformFee'] ?? 0.0);

    // --- NEW: Extract Coupon Info ---
    final couponCode = order['couponCode']?.toString();
    final couponDiscount = safeToDouble(order['couponDiscount']);

    double grandTotal = safeToDouble(
        order['grandTotal'] ??
            order['total'] ??
            order['finalAmount'] ??
            order['totalAmount'] ??
            order['finalTotal'] ??
            order['amount'] ??
            0.0
    );

    // Fix Grand Total Calculation
    if (grandTotal == 0.0) {
      // Subtract both general discount AND coupon discount
      grandTotal = subtotal + deliveryCharge + platformCharge + processingFee + tax - discountApplied - couponDiscount;
      if (grandTotal < 0) grandTotal = 0.0;
    } else if (grandTotal < 0) {
      grandTotal = subtotal + deliveryCharge + platformCharge + processingFee + tax - discountApplied - couponDiscount;
      if (grandTotal < 0) grandTotal = 0.0;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Summary', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isLoading) const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(orderNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: getStatusColor(status))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Dated: ${formatDate(createdAt)}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('${items.length} items in this order', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Order Items
            if (items.isNotEmpty)
              Container(
                color: Colors.white,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) => _buildOrderItem(items[index]),
                ),
              )
            else
              const Padding(padding: EdgeInsets.all(16), child: Text('No items found')),

            const SizedBox(height: 16),

            // Billing Details
            _buildBillingSection(
              subtotal: subtotal,
              deliveryCharge: deliveryCharge,
              platformCharge: platformCharge,
              processingFee: processingFee,
              tax: tax,
              discountApplied: discountApplied,
              couponCode: couponCode,        // Pass Code
              couponDiscount: couponDiscount, // Pass Discount
              grandTotal: grandTotal,
            ),

            const SizedBox(height: 16),
            _buildOrderDetailsSection(order),
            const SizedBox(height: 16),
            _buildHelpSupportSection(),
            const SizedBox(height: 32),

            // Re-Order Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _reorderItems(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Re Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final productName = item['productName'] ?? item['itemName'] ?? item['name'] ?? 'Unknown Product';
    final quantity = item['quantity'] ?? 1;
    final price = item['price'] ?? item['salesPrice'] ?? 0.0;
    final brand = item['brand'] ?? '';
    final imageUrl = item['productImage'] ?? item['itemImage'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(imageUrl.toString(), fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image_not_supported))
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                if (brand.isNotEmpty) Text(brand, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Qty: $quantity', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBillingSection({
    required double subtotal,
    required double deliveryCharge,
    required double platformCharge,
    required double processingFee,
    required double tax,
    required double discountApplied,
    required double grandTotal,
    String? couponCode,
    double couponDiscount = 0.0,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Billing Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),

          _buildBillingRow(icon: Icons.receipt_outlined, label: 'Subtotal', value: '₹${subtotal.toStringAsFixed(2)}'),
          _buildBillingRow(icon: Icons.delivery_dining_outlined, label: 'Delivery Charge', value: '₹${deliveryCharge.toStringAsFixed(2)}'),
          _buildBillingRow(icon: Icons.account_balance_wallet_outlined, label: 'Processing Fee', value: '₹${processingFee.toStringAsFixed(2)}'),
          _buildBillingRow(icon: Icons.receipt_long_outlined, label: 'Tax', value: '₹${tax.toStringAsFixed(2)}'),

          if (platformCharge != 0)
            _buildBillingRow(icon: Icons.payments_outlined, label: 'Platform Charges', value: '₹${platformCharge.toStringAsFixed(2)}'),

          // Generic Discount
          if (discountApplied > 0)
            _buildBillingRow(
              icon: Icons.discount_outlined,
              label: 'Discount Applied',
              value: '-₹${discountApplied.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),

          // --- NEW: Coupon Discount Section ---
          if (couponDiscount > 0)
            _buildBillingRow(
              icon: Icons.local_offer_outlined,
              label: 'Coupon ${couponCode != null ? "($couponCode)" : ""}',
              value: '-₹${couponDiscount.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),

          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),

          const SizedBox(height: 16),

          // Download Invoice Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: TextButton.icon(
              onPressed: _downloadInvoice,
              icon: Icon(Icons.download, color: Colors.orange[700]),
              label: Text('Download Invoice', style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingRow({required IconData icon, required String label, required String value, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsSection(Map<String, dynamic> order) {
    final orderId = order['_id'] ?? order['id'] ?? 'Unknown';
    final customerName = order['customerName'] ?? 'N/A';
    final customerPhone = order['customerPhone'] ?? 'N/A';
    final paymentMethod = order['paymentMethod'] ?? 'N/A';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildDetailRow('Order Id', orderId),
          _buildDetailRow('Customer', customerName),
          _buildDetailRow('Phone', customerPhone),
          _buildDetailRow('Payment Method', paymentMethod),
          _buildDetailRow('Delivery Type', order['isInstantDelivery'] == true ? 'Instant' : 'Scheduled'),
          if(order['scheduledDeliveryDate'] != null) _buildDetailRow('Scheduled Date', order['scheduledDeliveryDate']),
          if(order['scheduledDeliveryTime'] != null) _buildDetailRow('Scheduled Time', order['scheduledDeliveryTime']),
          const SizedBox(height: 12),
          Text('Delivery Address', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(_formatAddress(order), style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildHelpSupportSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Help & Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextButton.icon(
              onPressed: _openChat,
              icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[700]),
              label: Text('Chat with Us', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87))),
        ],
      ),
    );
  }

  String _formatAddress(Map<String, dynamic> order) {
    final houseNo = order['houseNo'] ?? '';
    final area = order['area'] ?? '';
    final city = order['city'] ?? '';
    final state = order['state'] ?? '';
    final postalCode = order['postalCode'] ?? '';

    List<String> parts = [houseNo, area, city, state, postalCode].where((s) => s.toString().isNotEmpty).cast<String>().toList();
    return parts.isEmpty ? 'Address not available' : parts.join(', ');
  }

  void _downloadInvoice() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice download coming soon!'), backgroundColor: Colors.orange));
  }

  void _openChat() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat feature coming soon!'), backgroundColor: Colors.blue));
  }

  void _reorderItems() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      await OrderService.reorderFromPreviousOrder(widget.orderId);
      if(mounted) Navigator.pop(context);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items added to cart!'), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) Navigator.pop(context);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}