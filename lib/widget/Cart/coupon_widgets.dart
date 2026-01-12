// lib/widget/Cart/coupon_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/Coupon/discount_coupon_service.dart';
import '../../model/cart/cart_item_model.dart';

class CouponModel {
  final String id;
  final String code; // Mapped from occasionName
  final String description;
  final String couponType;
  final double value;
  final double minOrderAmount;
  final DateTime? expiryDate;
  final bool isNewUserOnly;

  // Exclusion Lists (IDs)
  final List<String> excludedItemIds;
  final List<String> excludedCategoryIds;
  final List<String> excludedSubCategoryIds;
  final List<String> excludedSubSubCategoryIds;

  final List<String> termsAndConditions;

  CouponModel({
    required this.id,
    required this.code,
    required this.description,
    required this.couponType,
    required this.value,
    required this.minOrderAmount,
    this.expiryDate,
    this.isNewUserOnly = false,
    required this.excludedItemIds,
    required this.excludedCategoryIds,
    required this.excludedSubCategoryIds,
    required this.excludedSubSubCategoryIds,
    required this.termsAndConditions,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse the new structure: [ { "_id": "...", "name": "..." }, ... ]
    List<String> extractIdsFromObjects(dynamic list) {
      if (list == null || list is! List) return [];
      return list.map((item) {
        if (item is Map && item['_id'] != null) return item['_id'].toString();
        return '';
      }).where((s) => s.isNotEmpty).toList();
    }

    double minAmt = double.tryParse(json['minAmt']?.toString() ?? '0') ?? 0.0;

    List<String> terms = [];
    if (minAmt > 0) terms.add("Min order value: ₹${minAmt.toStringAsFixed(0)}");
    if (json['isNewUserOnly'] == true) terms.add("Valid for new users only");

    // Parse exclusions just for display/terms if needed
    // Logic for exclusion validation is now handled by the SERVER (applyCoupon)

    return CouponModel(
      id: json['_id']?.toString() ?? '',
      // The prompt indicates 'occasionName' is the identifier (e.g. "Order 1500")
      code: json['occasionName']?.toString() ?? json['code']?.toString() ?? 'OFFER',
      description: json['description']?.toString() ?? '',
      couponType: json['couponType']?.toString() ?? 'Fixed',
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0.0,
      minOrderAmount: minAmt,
      expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate']) : null,
      isNewUserOnly: json['isNewUserOnly'] ?? false,

      // New Extraction Logic for List<Map>
      excludedItemIds: extractIdsFromObjects(json['itemsNotAllowed']),
      excludedCategoryIds: extractIdsFromObjects(json['categoryNotAllowed']),
      excludedSubCategoryIds: extractIdsFromObjects(json['subCategoryNotAllowed']),
      excludedSubSubCategoryIds: extractIdsFromObjects(json['subsubCategoryNotAllowed']),

      termsAndConditions: terms,
    );
  }
}

// ... ApplyCouponWidget class remains mostly the same ...
class ApplyCouponWidget extends StatelessWidget {
  final CouponModel? appliedCoupon;
  final Function(CouponModel?, double) onApply; // Changed to accept discount amount
  final double currentCartTotal;
  final List<CartItem> cartItems;

  const ApplyCouponWidget({
    Key? key,
    this.appliedCoupon,
    required this.onApply,
    required this.currentCartTotal,
    required this.cartItems,
  }) : super(key: key);

  void _openCouponSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => CouponListSheet(
          scrollController: controller,
          currentCartTotal: currentCartTotal,
          cartItems: cartItems,
          onCouponSelected: onApply,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openCouponSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appliedCoupon != null ? Colors.green.shade50 : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: appliedCoupon != null ? Colors.green.shade700 : Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appliedCoupon != null ? 'Coupon Applied' : 'Apply Coupon',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appliedCoupon != null
                            ? '${appliedCoupon!.code} • Savings applied!'
                            : 'See available offers',
                        style: TextStyle(
                          fontSize: 12,
                          color: appliedCoupon != null ? Colors.green.shade700 : Colors.grey.shade500,
                          fontWeight: appliedCoupon != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (appliedCoupon != null)
                  InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onApply(null, 0.0); // Clear coupon
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('REMOVE', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CouponListSheet extends StatefulWidget {
  final ScrollController scrollController;
  final double currentCartTotal;
  final List<CartItem> cartItems;
  final Function(CouponModel, double) onCouponSelected; // Accepts Coupon and Actual Discount

  const CouponListSheet({
    Key? key,
    required this.scrollController,
    required this.currentCartTotal,
    required this.cartItems,
    required this.onCouponSelected,
  }) : super(key: key);

  @override
  State<CouponListSheet> createState() => _CouponListSheetState();
}

class _CouponListSheetState extends State<CouponListSheet> {
  late Future<List<CouponModel>> _couponsFuture;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _couponsFuture = _fetchCoupons();
  }

  Future<List<CouponModel>> _fetchCoupons() async {
    final result = await DiscountCouponService.getCoupons();
    if (result['success'] == true) {
      final List data = result['data'] is List ? result['data'] : [];
      return data.map((json) => CouponModel.fromJson(json)).toList();
    }
    throw Exception(result['error'] ?? 'Failed to load coupons');
  }

  // UPDATED: Now calls Server-Side Verification
  Future<void> _handleApply(CouponModel coupon) async {
    // 1. Basic pre-checks (optional, but saves a network call)
    if (widget.currentCartTotal < coupon.minOrderAmount) {
      _showSnack('Minimum order value is ₹${coupon.minOrderAmount}', isError: true);
      return;
    }

    setState(() => _isApplying = true);

    // 2. Call the Server API to validate and get actual discount
    final result = await DiscountCouponService.applyCoupon(
      occasionName: coupon.code,
      orderAmount: widget.currentCartTotal,
      cartItems: widget.cartItems,
    );

    setState(() => _isApplying = false);

    if (result['success'] == true) {
      double serverDiscount = result['discount'] ?? 0.0;

      // Pass back the coupon AND the server-calculated discount
      widget.onCouponSelected(coupon, serverDiscount);

      if (mounted) Navigator.pop(context);
      _showSnack(result['message'] ?? 'Coupon Applied!', isError: false);
    } else {
      _showSnack(result['error'] ?? 'Could not apply coupon', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Available Coupons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          if (_isApplying)
            LinearProgressIndicator(color: Colors.brown.shade800, backgroundColor: Colors.brown.shade100),

          Expanded(
            child: FutureBuilder<List<CouponModel>>(
              future: _couponsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.brown));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No coupons available'));
                }
                final coupons = snapshot.data!;
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: coupons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return CouponCard(
                      coupon: coupons[index],
                      currentCartTotal: widget.currentCartTotal,
                      onApply: () => _handleApply(coupons[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ... CouponCard remains unchanged ...
class CouponCard extends StatefulWidget {
  final CouponModel coupon;
  final double currentCartTotal;
  final VoidCallback onApply;
  const CouponCard({Key? key, required this.coupon, required this.currentCartTotal, required this.onApply}) : super(key: key);
  @override
  State<CouponCard> createState() => _CouponCardState();
}
class _CouponCardState extends State<CouponCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.coupon.code, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(widget.coupon.description),
            trailing: TextButton(onPressed: widget.onApply, child: Text('APPLY')),
          ),
          if (widget.coupon.termsAndConditions.isNotEmpty)
            ExpansionTile(
              title: Text("Terms & Conditions", style: TextStyle(fontSize: 12)),
              children: widget.coupon.termsAndConditions.map((t) => ListTile(
                dense: true, title: Text(t, style: TextStyle(fontSize: 11)),
              )).toList(),
            )
        ],
      ),
    );
  }
}