import 'package:flutter/material.dart';

/// A widget that displays options for adding a tip and a donation.
///
/// This widget is self-contained and requires callbacks to manage state
/// in the parent widget.
class CartOptionsWidgets extends StatelessWidget {
  final String selectedTipAmount;
  final String selectedDonationAmount;
  final Function(String, double) onUpdateTip;
  final Function(String, double) onUpdateDonation;
  final VoidCallback onShowCustomTipDialog;

  const CartOptionsWidgets({
    super.key,
    required this.selectedTipAmount,
    required this.selectedDonationAmount,
    required this.onUpdateTip,
    required this.onUpdateDonation,
    required this.onShowCustomTipDialog,
  });

  @override
  Widget build(BuildContext context) {
    // Returns a column containing both the tip and donation sections.
    return Column(
      children: [
        _buildTipSection(),
        _buildDonationSection(),
      ],
    );
  }

  /// Builds the UI section for adding a tip for the delivery partner.
  Widget _buildTipSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown.shade800, Colors.brown.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tip for your delivery partner',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Show appreciation for good service',
            style: TextStyle(color: Colors.brown.shade100, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTipButton('₹10', 10.0),
              _buildTipButton('₹15', 15.0),
              _buildTipButton('₹20', 20.0),
              _buildTipButton('₹25', 25.0),
              _buildTipButton('CUSTOM', 0.0),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a single, pressable tip amount button.
  Widget _buildTipButton(String amount, double value) {
    bool isSelected = selectedTipAmount == amount;
    return GestureDetector(
      onTap: () {
        if (amount == 'CUSTOM') {
          onShowCustomTipDialog();
        } else {
          // Toggle selection
          if (isSelected) {
            onUpdateTip('', 0.0);
          } else {
            onUpdateTip(amount, value);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.amber.shade900, width: 2)
              : Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, size: 16, color: Colors.white),
              ),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.brown.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the UI section for making a donation.
  Widget _buildDonationSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.amber.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Donation for Needy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Help those in need with your kindness',
            style: TextStyle(color: Colors.amber.shade100, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDonationButton('₹5', 5.0),
              _buildDonationButton('₹10', 10.0),
              _buildDonationButton('₹15', 15.0),
              _buildDonationButton('₹20', 20.0),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a single, pressable donation amount button.
  Widget _buildDonationButton(String amount, double value) {
    bool isSelected = selectedDonationAmount == amount;
    return GestureDetector(
      onTap: () {
        // Toggle selection
        if (isSelected) {
          onUpdateDonation('', 0.0);
        } else {
          onUpdateDonation(amount, value);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.orange.shade900, width: 2)
              : Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, size: 16, color: Colors.white),
              ),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.amber.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}