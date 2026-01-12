// screens/checkout_screen.dart
// import 'package:flutter/material.dart';
// import '../../authentication/user_data.dart';
// import '../../services/Order/order_api_service.dart';
//
// class CheckoutScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> cartItems;
//   final double subtotal;
//   final double deliveryFee;
//   final double platformFee;
//   final double cartFee;
//   final double selectedTip;
//   final double selectedDonation;
//   final bool isInstantDelivery;
//
//   const CheckoutScreen({
//     Key? key,
//     required this.cartItems,
//     required this.subtotal,
//     required this.deliveryFee,
//     required this.platformFee,
//     required this.cartFee,
//     required this.selectedTip,
//     required this.selectedDonation,
//     required this.isInstantDelivery,
//   }) : super(key: key);
//
//   @override
//   State<CheckoutScreen> createState() => _CheckoutScreenState();
// }
//
// class _CheckoutScreenState extends State<CheckoutScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _userData = UserData();
//
//   // Form Controllers
//   final _houseNoController = TextEditingController();
//   final _areaController = TextEditingController();
//   final _cityController = TextEditingController();
//   final _stateController = TextEditingController();
//   final _postalCodeController = TextEditingController();
//   final _locationController = TextEditingController();
//
//   // State variables
//   bool _isLoading = false;
//
//   // Checkout session data
//   String? _checkoutSessionId;
//
//   // Calculated values
//   double get _grandTotal =>
//       widget.subtotal +
//       widget.deliveryFee +
//       widget.platformFee +
//       widget.cartFee +
//       widget.selectedTip +
//       widget.selectedDonation;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeForm();
//     _initializeCheckout();
//   }
//
//   void _initializeForm() {
//     // Pre-fill form with user data
//     _cityController.text = _userData.getCity();
//     _stateController.text = _userData.getState();
//   }
//
//   @override
//   void dispose() {
//     _houseNoController.dispose();
//     _areaController.dispose();
//     _cityController.dispose();
//     _stateController.dispose();
//     _postalCodeController.dispose();
//     _locationController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _initializeCheckout() async {
//     setState(() => _isLoading = true);
//
//     try {
//       final response = await OrderService.createCheckoutSession();
//
//       setState(() {
//         _checkoutSessionId = response['checkoutSessionId'];
//       });
//     } catch (e) {
//       _showErrorDialog('Failed to initialize checkout: ${e.toString()}');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _placeOrder() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isLoading = true);
//
//     try {
//       if (_checkoutSessionId != null) {
//         final orderResponse = await OrderService.placeOrderFromSession(
//           checkoutSessionId: _checkoutSessionId!,
//           houseNo: _houseNoController.text,
//           area: _areaController.text,
//           city: _cityController.text,
//           state: _stateController.text,
//           postalCode: _postalCodeController.text,
//           locationLink: _locationController.text,
//           tax: widget.platformFee, // Using platform fee as tax
//           shippingFee: widget.deliveryFee,
//           discountApplied: 0.0,
//         );
//
//         if (orderResponse['success'] == true) {
//           _showOrderConfirmationDialog();
//         } else {
//           _showErrorDialog('Failed to place order');
//         }
//       } else {
//         _showErrorDialog('Checkout session not initialized');
//       }
//     } catch (e) {
//       _showErrorDialog('Error placing order: ${e.toString()}');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _showOrderConfirmationDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder:
//           (context) => AlertDialog(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//             ),
//             title: Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.green, size: 30),
//                 SizedBox(width: 12),
//                 Text('Order Placed Successfully!'),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Hi ${_userData.getName()}!'),
//                 SizedBox(height: 8),
//                 Text('Your order has been placed successfully!'),
//                 SizedBox(height: 16),
//                 Container(
//                   padding: EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Order ID: #${DateTime.now().millisecondsSinceEpoch}',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       SizedBox(height: 4),
//                       Text(
//                         'Order Total: ₹${_grandTotal.toStringAsFixed(2)}',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       if (widget.selectedTip > 0)
//                         Text('Tip: ₹${widget.selectedTip.toStringAsFixed(2)}'),
//                       if (widget.selectedDonation > 0)
//                         Text(
//                           'Donation: ₹${widget.selectedDonation.toStringAsFixed(2)}',
//                         ),
//                       Text(
//                         'Delivery: ${widget.isInstantDelivery ? "Instant" : "Standard"}',
//                       ),
//                       Text('Payment: Cash on Delivery'),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 12),
//                 Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.orange.shade200),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.info, color: Colors.orange, size: 16),
//                       SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'Please keep exact change ready (₹${_grandTotal.toStringAsFixed(2)})',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.orange.shade800,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   Navigator.popUntil(context, (route) => route.isFirst);
//                 },
//                 child: Text('Continue Shopping'),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   Navigator.popUntil(context, (route) => route.isFirst);
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.white,
//                 ),
//                 child: Text('OK'),
//               ),
//             ],
//           ),
//     );
//   }
//
//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//             ),
//             title: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.red, size: 30),
//                 SizedBox(width: 12),
//                 Text('Error'),
//               ],
//             ),
//             content: Text(message),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('OK'),
//               ),
//             ],
//           ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         title: Text('Checkout'),
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         elevation: 1,
//       ),
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: EdgeInsets.all(16.0),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       children: [
//                         _buildUserInfo(),
//                         SizedBox(height: 16),
//                         _buildOrderSummary(),
//                         SizedBox(height: 16),
//                         _buildAddressForm(),
//                         SizedBox(height: 16),
//                         _buildPaymentMethod(),
//                         SizedBox(height: 16),
//                         _buildPriceBreakdown(),
//                         SizedBox(height: 100),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           if (_isLoading)
//             Container(
//               color: Colors.black54,
//               child: Center(
//                 child: CircularProgressIndicator(color: Colors.white),
//               ),
//             ),
//         ],
//       ),
//       bottomSheet: _buildBottomSheet(),
//     );
//   }
//
//   Widget _buildUserInfo() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Row(
//           children: [
//             CircleAvatar(
//               radius: 25,
//               backgroundColor: Colors.brown.shade100,
//               child: Text(
//                 _userData.getName().isNotEmpty
//                     ? _userData.getName()[0].toUpperCase()
//                     : 'U',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.brown.shade700,
//                 ),
//               ),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     _userData.getName(),
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                   Text(
//                     _userData.getPhone(),
//                     style: TextStyle(color: Colors.grey[600]),
//                   ),
//                   if (_userData.getEmail().isNotEmpty)
//                     Text(
//                       _userData.getEmail(),
//                       style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildOrderSummary() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Order Summary',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 12),
//             ...widget.cartItems
//                 .map(
//                   (item) => Padding(
//                     padding: EdgeInsets.only(bottom: 8.0),
//                     child: Row(
//                       children: [
//                         Container(
//                           width: 50,
//                           height: 50,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(8),
//                             color: Colors.brown.shade100,
//                           ),
//                           child: Center(
//                             child: Text(
//                               item['name'][0].toUpperCase(),
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.brown.shade700,
//                               ),
//                             ),
//                           ),
//                         ),
//                         SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item['name'],
//                                 style: TextStyle(fontWeight: FontWeight.w500),
//                               ),
//                               Text(
//                                 'Qty: ${item['quantity']}',
//                                 style: TextStyle(
//                                   color: Colors.grey[600],
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Text(
//                           '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       ],
//                     ),
//                   ),
//                 )
//                 .toList(),
//             Divider(),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Subtotal:',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   '₹${widget.subtotal.toStringAsFixed(2)}',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAddressForm() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Delivery Address',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 12),
//             TextFormField(
//               controller: _houseNoController,
//               decoration: InputDecoration(
//                 labelText: 'House/Flat No.',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 prefixIcon: Icon(Icons.home),
//               ),
//               validator:
//                   (value) =>
//                       value?.isEmpty ?? true
//                           ? 'House number is required'
//                           : null,
//             ),
//             SizedBox(height: 12),
//             TextFormField(
//               controller: _areaController,
//               decoration: InputDecoration(
//                 labelText: 'Area/Street',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 prefixIcon: Icon(Icons.location_on),
//               ),
//               validator:
//                   (value) => value?.isEmpty ?? true ? 'Area is required' : null,
//             ),
//             SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     controller: _cityController,
//                     decoration: InputDecoration(
//                       labelText: 'City',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       prefixIcon: Icon(Icons.location_city),
//                     ),
//                     validator:
//                         (value) =>
//                             value?.isEmpty ?? true ? 'City is required' : null,
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: TextFormField(
//                     controller: _stateController,
//                     decoration: InputDecoration(
//                       labelText: 'State',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       prefixIcon: Icon(Icons.map),
//                     ),
//                     validator:
//                         (value) =>
//                             value?.isEmpty ?? true ? 'State is required' : null,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 12),
//             TextFormField(
//               controller: _postalCodeController,
//               decoration: InputDecoration(
//                 labelText: 'Postal Code',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 prefixIcon: Icon(Icons.pin_drop),
//               ),
//               keyboardType: TextInputType.number,
//               validator: (value) {
//                 if (value?.isEmpty ?? true) return 'Postal code is required';
//                 if (value!.length != 6)
//                   return 'Please enter valid 6-digit postal code';
//                 return null;
//               },
//             ),
//             SizedBox(height: 12),
//             TextFormField(
//               controller: _locationController,
//               decoration: InputDecoration(
//                 labelText: 'Landmark (Optional)',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 prefixIcon: Icon(Icons.location_searching),
//               ),
//               maxLines: 2,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPaymentMethod() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Payment Method',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 12),
//             Container(
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.brown.shade50,
//                 border: Border.all(color: Colors.brown.shade800, width: 2),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.money, color: Colors.brown.shade800, size: 24),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Cash on Delivery',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.brown.shade700,
//                           ),
//                         ),
//                         Text(
//                           'Pay when your order arrives',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.brown.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   Icon(Icons.check_circle, color: Colors.brown.shade800),
//                 ],
//               ),
//             ),
//             SizedBox(height: 8),
//             Container(
//               padding: EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.blue.shade50,
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.info, color: Colors.blue, size: 16),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Please keep exact change ready. Our delivery partner will collect ₹${_grandTotal.toStringAsFixed(2)}',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.blue.shade700,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPriceBreakdown() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Price Breakdown',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 12),
//             _buildPriceRow('Subtotal', widget.subtotal),
//             _buildPriceRow('Delivery Fee', widget.deliveryFee),
//             _buildPriceRow('Platform Fee', widget.platformFee),
//             _buildPriceRow('Cart Fee', widget.cartFee),
//             if (widget.selectedTip > 0)
//               _buildPriceRow('Tip', widget.selectedTip),
//             if (widget.selectedDonation > 0)
//               _buildPriceRow('Donation', widget.selectedDonation),
//             Divider(thickness: 2),
//             _buildPriceRow('Total', _grandTotal, isTotal: true),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: isTotal ? 16 : 14,
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//           Text(
//             '₹${amount.toStringAsFixed(2)}',
//             style: TextStyle(
//               fontSize: isTotal ? 16 : 14,
//               fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
//               color: isTotal ? Colors.brown.shade800 : Colors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBottomSheet() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.shade300,
//             blurRadius: 10,
//             offset: Offset(0, -2),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Row(
//           children: [
//             Expanded(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Total Amount',
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   ),
//                   Text(
//                     '₹${_grandTotal.toStringAsFixed(2)}',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.brown.shade800,
//                     ),
//                   ),
//                   Text(
//                     'Cash on Delivery',
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(width: 16),
//             Expanded(
//               child: ElevatedButton(
//                 onPressed: _isLoading ? null : _placeOrder,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.brown.shade800,
//                   foregroundColor: Colors.white,
//                   padding: EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child:
//                     _isLoading
//                         ? SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             valueColor: AlwaysStoppedAnimation<Color>(
//                               Colors.white,
//                             ),
//                           ),
//                         )
//                         : Text(
//                           'Place Order',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }*/
