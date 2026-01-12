/*import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentMethodWidget extends StatefulWidget {
  final double grandTotal;
  final Function(String)? onPaymentMethodChanged;
  final Function(PaymentSuccessResponse)? onPaymentSuccess;
  final Function(PaymentFailureResponse)? onPaymentFailure;
  final Function()? onPaymentError;

  const PaymentMethodWidget({
    Key? key,
    required this.grandTotal,
    this.onPaymentMethodChanged,
    this.onPaymentSuccess,
    this.onPaymentFailure,
    this.onPaymentError,
  }) : super(key: key);

  @override
  State<PaymentMethodWidget> createState() => _PaymentMethodWidgetState();
}

class _PaymentMethodWidgetState extends State<PaymentMethodWidget> {
  String selectedPaymentMethod = 'COD'; // Default selection
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    widget.onPaymentSuccess?.call(response);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Successful! ID: ${response.paymentId}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    widget.onPaymentFailure?.call(response);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void openRazorpayCheckout() {
    _openRazorpayCheckout();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet: ${response.walletName}'),
      ),
    );
  }

  void _openRazorpayCheckout() {
    var options = {
      'key': 'rzp_live_RN5l7ppvEWmNxm', // Replace with your Razorpay key
      'amount': (widget.grandTotal * 100).toInt(), // Amount in paise
      'name': 'Grocery On Wheels ',
      'description': 'Order Payment',
      'prefill': {
        'contact': '9999999999',
        'email': 'customer@example.com'
      },
      'theme': {
        'color': '#795548' // Brown color to match theme
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      widget.onPaymentError?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

        // Cash on Delivery Option
        GestureDetector(
          onTap: () {
            setState(() {
              selectedPaymentMethod = 'COD';
            });
            widget.onPaymentMethodChanged?.call('COD');
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
                  child: const Icon(Icons.money, color: Colors.white, size: 20),
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
                        'Pay ₹${widget.grandTotal.toStringAsFixed(2)} when order arrives',
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

        const SizedBox(height: 12),

        // Online Payment Option
        GestureDetector(
          onTap: () {
            setState(() {
              selectedPaymentMethod = 'Online';
            });
            widget.onPaymentMethodChanged?.call('Online');
            // Remove _openRazorpayCheckout() from here
            // It should only open when user clicks "Place Order"
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
                  child: const Icon(Icons.credit_card, color: Colors.white, size: 20),
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
                        'Pay ₹${widget.grandTotal.toStringAsFixed(2)} via UPI, Card or Net Banking',
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
      ],
    );
  }
}*/