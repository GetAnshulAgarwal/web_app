import 'package:flutter/foundation.dart';

import '../authentication/user_data.dart';
import '../model/Address/address_model.dart';
import '../services/Address/address_service.dart';

class AddressProvider extends ChangeNotifier {
  AddressProvider() {
    // Load cached addresses immediately when provider is created
    loadAddresses();
  }
  List<Address> _addresses = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Address> get addresses => List.unmodifiable(_addresses);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAddresses => _addresses.isNotEmpty;

  Address? get defaultAddress {
    if (_addresses.isEmpty) return null;
    try {
      return _addresses.firstWhere((address) => address.isDefault);
    } catch (e) {
      return _addresses.first;
    }
  }

  // Load all addresses
  Future<void> loadAddresses() async {
    _clearError();

    // Try cached addresses first for immediate UI
    try {
      final cached = await AddressService.readAddressesFromCache();
      if (cached != null && cached.isNotEmpty) {
        _addresses = cached;
        _sortAddresses();
        debugPrint('Loaded ${_addresses.length} cached addresses');
        notifyListeners();

        // Refresh in background
        _refreshAddressesFromNetwork();
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to read cached addresses: $e');
      // fall through to network fetch
    }

    _setLoading(true);

    try {
      final userData = UserData();
      if (!userData.isLoggedIn()) {
        throw Exception('User not authenticated. Please login again.');
      }

      _addresses = await AddressService.fetchAddresses();
      _sortAddresses();

      debugPrint('Loaded ${_addresses.length} addresses');
      for (var address in _addresses) {
        debugPrint(
          'Address: ${address.id} - ${address.label} - Default: ${address.isDefault}',
        );
      }

      // Cache addresses for future quick loads
      try {
        await AddressService.saveAddressesToCache(_addresses);
      } catch (_) {}
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error loading addresses: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Background refresh that updates cache and notifies listeners
  Future<void> _refreshAddressesFromNetwork() async {
    try {
      final userData = UserData();
      if (!userData.isLoggedIn()) return;

      final fresh = await AddressService.fetchAddresses();
      if (fresh.isNotEmpty) {
        _addresses = fresh;
        _sortAddresses();

        try {
          await AddressService.saveAddressesToCache(_addresses);
        } catch (e) {
          debugPrint('⚠️ Failed to cache addresses after refresh: $e');
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Background address refresh failed: $e');
    }
  }

  // Add new address
  Future<void> addAddress(Address address) async {
    try {
      _clearError();

      debugPrint(
        'Adding address: ${address.label}, Default: ${address.isDefault}',
      );

      // Create the address via API
      final newAddress = await AddressService.createAddress(address);

      debugPrint('Address created successfully: ${newAddress.id}');

      // Add the new address to the list
      _addresses.add(newAddress);
      _sortAddresses();
      notifyListeners();

      debugPrint('Address added successfully: ${newAddress.id}');
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error adding address: $e');
      rethrow;
    }
  }

  // Update existing address
  Future<void> updateAddress(Address address) async {
    try {
      _clearError();

      debugPrint('Updating address: ${address.id} - ${address.label}');

      // Validate that this is an existing address (has valid ID)
      if (address.id.isEmpty) {
        throw Exception('Cannot update address without valid ID');
      }

      final updatedAddress = await AddressService.updateAddress(
        address.id,
        address,
      );

      debugPrint('Address updated successfully: ${updatedAddress.id}');

      final index = _addresses.indexWhere((a) => a.id == address.id);
      if (index != -1) {
        _addresses[index] = updatedAddress;
        _sortAddresses();
        notifyListeners();
      } else {
        throw Exception('Address not found in local list');
      }
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error updating address: $e');
      rethrow;
    }
  }

  // Delete address
  Future<void> deleteAddress(String id) async {
    try {
      _clearError();

      debugPrint('Deleting address: $id');

      if (id.isEmpty) {
        throw Exception('Cannot delete address with empty ID');
      }

      final success = await AddressService.deleteAddress(id);

      if (success) {
        _addresses.removeWhere((address) => address.id == id);
        notifyListeners();
        debugPrint('Address deleted successfully');
      } else {
        throw Exception('Failed to delete address');
      }
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error deleting address: $e');
      rethrow;
    }
  }

  // Set address as default - THIS IS THE KEY FIX
  Future<void> setDefaultAddress(String id) async {
    try {
      _clearError();

      debugPrint('Setting default address: $id');

      // Validate the ID first
      if (id.isEmpty) {
        throw Exception('Cannot set default address with empty ID');
      }

      // Find the address to make default
      final addressIndex = _addresses.indexWhere((a) => a.id == id);
      if (addressIndex == -1) {
        debugPrint(
          'Available addresses: ${_addresses.map((a) => '${a.id} - ${a.label}').join(', ')}',
        );
        throw Exception('Address not found with ID: $id');
      }

      final currentAddress = _addresses[addressIndex];
      debugPrint('Found address: ${currentAddress.label}');

      // If it's already default, no need to update
      if (currentAddress.isDefault) {
        debugPrint('Address is already default');
        return;
      }

      // Create updated address with isDefault = true
      final updatedAddress = currentAddress.copyWith(isDefault: true);

      debugPrint('Calling API to set as default...');

      // Call the API to update the address
      final serverUpdatedAddress = await AddressService.updateAddress(
        id,
        updatedAddress,
      );

      debugPrint('API call successful');

      // Update the local state - this is the key fix
      // First, set all addresses to not default
      for (int i = 0; i < _addresses.length; i++) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }

      // Then set the selected address as default
      _addresses[addressIndex] = serverUpdatedAddress;

      _sortAddresses();
      notifyListeners();

      debugPrint('Default address set successfully');
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error setting default address: $e');
      rethrow;
    }
  }

  // Get address by ID
  Address? getAddressById(String id) {
    try {
      return _addresses.firstWhere((address) => address.id == id);
    } catch (e) {
      return null;
    }
  }

  // Refresh addresses
  Future<void> refreshAddresses() async {
    await loadAddresses();
  }

  // Check if user is authenticated and redirect if not
  Future<bool> checkAuthenticationAndRedirect() async {
    try {
      final userData = UserData();
      if (!userData.isLoggedIn()) {
        _setError('Please login to manage addresses');
        return false;
      }
      return true;
    } catch (e) {
      _setError('Authentication error: ${e.toString()}');
      return false;
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void _sortAddresses() {
    _addresses.sort((a, b) {
      // Default address first
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;

      // Then by most recently updated
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
