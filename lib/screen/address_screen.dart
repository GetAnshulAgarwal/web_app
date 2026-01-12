import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

import '../model/Address/address_model.dart';
import '../providers/address_provider.dart';
import '../providers/location_provider.dart';
import '../utils/constants.dart';
import '../widget/Address/address_card.dart';
import '../widget/Address/address_selector_modal.dart';
import '../widget/Address/empty_address_state.dart';
import 'Address/add_edit_address_screen.dart';

class AddressScreen extends StatefulWidget {
  final bool isSelectionMode;

  const AddressScreen({
    Key? key,
    this.isSelectionMode = false,
  }) : super(key: key);

  @override
  _AddressScreenState createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Consumer<AddressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          if (provider.error != null) {
            return _buildErrorState(provider);
          }

          if (!provider.hasAddresses) {
            return EmptyAddressState(onAddAddress: _navigateToAddAddress);
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshAddresses(),
            color: AppColors.primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.addresses.length,
              itemBuilder: (context, index) {
                final address = provider.addresses[index];
                return AddressCard(
                  address: address,
                  onEdit: () => _navigateToEditAddress(address),
                  onDelete: () => _showDeleteConfirmation(address),
                  onSetDefault: () => _setDefaultAddress(address),
                  onTap: widget.isSelectionMode ? () => _selectAddress(address) : null,
                  isSelectionMode: widget.isSelectionMode,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.isSelectionMode ? 'Select Address' : 'Address',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (!widget.isSelectionMode)
          Consumer<AddressProvider>(
            builder: (context, provider, child) {
              if (provider.hasAddresses) {
                return TextButton(
                  onPressed: _showAddressSelector,
                  child: const Text(
                    'Select',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildErrorState(AddressProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'Unknown error occurred',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    provider.clearError();
                    provider.loadAddresses();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (provider.error?.contains('authentication') == true ||
                    provider.error?.contains('login') == true)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                            (route) => false,
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddAddress,
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add),
      label: const Text(
        'Add Address',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _selectAddress(Address address) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primaryGreen),
                const SizedBox(height: 16),
                const Text('Checking delivery availability...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await context
          .read<LocationProvider>()
          .setManualAddressWithZoneCheck(address);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true && result['isServiceable'] == true) {
        //  SUCCESS: Show Delivery Animation
        await _showAnimationDialog(
          assetPath: 'assets/animations/dlivery.json',
          message: 'Address Selected!',
        );

        if (mounted) {
          Navigator.pop(context, true); // Return to previous screen
        }
      } else {
        //  FAILURE: Show Nodel (No Delivery) Animation
        await _showAnimationDialog(
          assetPath: 'assets/animations/nodel.json',
          message: result['message'] ?? 'Not Serviceable',
          isError: true,
        );
        // Do NOT pop context here, allow user to select another address
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showErrorMessage('Failed to select address: ${e.toString()}');
    }
  }

  // ✅ Generic Animation Dialog (Handles both Success and No Delivery)
  Future<void> _showAnimationDialog({
    required String assetPath,
    required String message,
    bool isError = false,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Auto-close after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Lottie.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        repeat: false,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isError ? AppColors.errorRed : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddressSelector() {
    final provider = context.read<AddressProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressSelectorModal(
        addresses: provider.addresses,
        onAddressSelected: _setDefaultAddress,
      ),
    );
  }

  void _navigateToAddAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
    );

    if (result != null && result is Address) {
      try {
        await context.read<AddressProvider>().addAddress(result);
        _showSuccessMessage('Address added successfully');
      } catch (e) {
        _showErrorMessage('Failed to add address: ${e.toString()}');
      }
    }
  }

  void _navigateToEditAddress(Address address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAddressScreen(address: address),
      ),
    );

    if (result != null && result is Address) {
      try {
        await context.read<AddressProvider>().updateAddress(result);
        _showSuccessMessage('Address updated successfully');
      } catch (e) {
        _showErrorMessage('Failed to update address: ${e.toString()}');
      }
    }
  }

  void _setDefaultAddress(Address address) async {
    if (address.isDefault) return;

    if (!address.isValid) {
      _showErrorMessage('Invalid address data');
      return;
    }

    try {
      await context.read<AddressProvider>().setDefaultAddress(address.id);
      _showSuccessMessage('Default address updated');
    } catch (e) {
      _showErrorMessage('Failed to set default address: ${e.toString()}');
    }
  }

  void _showDeleteConfirmation(Address address) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Address',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete "${address.label}" address?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAddress(address);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'DELETE',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteAddress(Address address) async {
    try {
      await context.read<AddressProvider>().deleteAddress(address.id);
      _showSuccessMessage('Address deleted successfully');
    } catch (e) {
      _showErrorMessage('Failed to delete address: ${e.toString()}');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}