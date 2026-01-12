import 'package:flutter/material.dart';

class PriceSummaryWidget extends StatelessWidget {
  final double totalAmount;
  final double deliveryFee;
  final double handlingFee;
  final String deliveryFeeName;
  final String handlingFeeName;
  final double selectedTip;
  final double selectedDonation;
  final double grandTotal;
  final bool isFreeDelivery;
  final String? thresholdMessage;
  final double? thresholdAmount;
  final double discountAmount; // Points/Wallet discount
  final double couponDiscount; // <-- NEW: Coupon discount

  const PriceSummaryWidget({
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
    this.couponDiscount = 0.0, // <-- NEW: Default to 0.0
    this.isFreeDelivery = false,
    this.thresholdMessage,
    this.thresholdAmount,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the final total to display (ensuring discounts are subtracted)
    // Assuming grandTotal passed in already has these subtracted, we just display them here.

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt, size: 20, color: Colors.brown),
              const SizedBox(width: 8),
              const Text(
                'Price Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items total
          _buildPriceRow('Items total', totalAmount),

          // Delivery Fee with free delivery badge
          Row(
            children: [
              Expanded(
                child: Text(
                  deliveryFeeName,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
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
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
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

          // Handling Fee
          _buildPriceRow(handlingFeeName, handlingFee),

          // Tip for delivery partner
          if (selectedTip > 0) _buildPriceRow('Tip', selectedTip),

          // Donation
          if (selectedDonation > 0)
            _buildPriceRow('Donation', selectedDonation),

          // Wallet/Points Discount
          if (discountAmount > 0)
            _buildPriceRow('Points Redeemed', -discountAmount, textColor: Colors.green),

          // Coupon Discount (NEW)
          if (couponDiscount > 0)
            _buildPriceRow('Coupon Discount', -couponDiscount, textColor: Colors.green),

          const Divider(height: 24),

          // Total (Using the grandTotal passed in, which should already have discounts subtracted)
          _buildPriceRow('Total', grandTotal, isTotal: true),

          // Savings badge if free delivery
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

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? (isTotal ? Colors.brown.shade800 : Colors.black87),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: textColor ?? (isTotal ? Colors.brown.shade800 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}