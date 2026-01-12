import 'package:flutter/material.dart';

class BillingDetailsWidget extends StatelessWidget {
  final double totalAmount;
  final double deliveryFee;
  final double handlingFee;
  final String deliveryFeeName;
  final String handlingFeeName;
  final double selectedTip;
  final double selectedDonation;
  final double grandTotal;
  final bool isFreeDelivery;
  final double discountAmount;
  final String? thresholdMessage;
  final double? thresholdAmount;

  // Coupon fields
  final double couponDiscount;
  final String? couponCode;

  const BillingDetailsWidget({
    super.key,
    required this.totalAmount,
    required this.deliveryFee,
    required this.handlingFee,
    required this.deliveryFeeName,
    required this.handlingFeeName,
    required this.selectedTip,
    required this.selectedDonation,
    required this.grandTotal,
    required this.discountAmount,
    this.isFreeDelivery = false,
    this.thresholdMessage,
    this.thresholdAmount,
    this.couponDiscount = 0.0,
    this.couponCode,
  });

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Icon(Icons.receipt_long, size: 20, color: Colors.brown),
              SizedBox(width: 8),
              Text(
                'Billing Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items total
          _buildBillingRow(
            Icons.list_alt,
            'Items total',
            '₹${totalAmount.toStringAsFixed(2)}',
          ),

          // Delivery Fee
          Row(
            children: [
              Icon(Icons.local_shipping, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deliveryFeeName,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ),
              if (isFreeDelivery && deliveryFee == 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'FREE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '₹${deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Show threshold message if delivery fee is applicable
          if (!isFreeDelivery &&
              thresholdMessage != null &&
              thresholdAmount != null)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thresholdMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add ₹${(thresholdAmount! - totalAmount).toStringAsFixed(2)} more for free delivery',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Processing Fee
          _buildBillingRow(
            Icons.receipt,
            handlingFeeName,
            '₹${handlingFee.toStringAsFixed(2)}',
          ),

          // Discount
          if (discountAmount > 0)
            _buildBillingRow(
              Icons.discount,
              'Discount',
              '- ₹${discountAmount.toStringAsFixed(2)}',
            ),

          // Tip for delivery partner
          if (selectedTip > 0)
            _buildBillingRow(
              Icons.person,
              'Tip for delivery partner',
              '₹${selectedTip.toStringAsFixed(2)}',
            ),

          // Donation
          if (selectedDonation > 0)
            _buildBillingRow(
              Icons.favorite,
              'Donation for Needy',
              '₹${selectedDonation.toStringAsFixed(2)}',
            ),

          // ✅ COUPON DISCOUNT FIELD (Shown only when discount > 0)
          if (couponDiscount > 0)
            _buildBillingRow(
              Icons.local_offer_outlined,
              'Coupon Discount ${couponCode != null ? "($couponCode)" : ""}',
              '-₹${couponDiscount.toStringAsFixed(2)}',
              isDiscount: true, // This triggers green color
            ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '₹${(grandTotal - discountAmount).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.brown.shade800,
                ),
              ),
            ],
          ),

          // Savings Badge
          if (isFreeDelivery && deliveryFee == 0 && thresholdAmount != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.celebration,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yay! You saved on delivery charges',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillingRow(IconData icon, String title, String amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
              icon,
              size: 16,
              color: isDiscount ? Colors.green.shade700 : Colors.grey.shade600
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isDiscount ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: isDiscount ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
