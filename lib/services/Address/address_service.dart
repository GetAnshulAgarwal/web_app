import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../authentication/user_data.dart';
import '../../model/Address/address_model.dart';
import '../cache/cache_manager.dart';

class AddressService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/addresses';

  // Get headers with authorization
  static Map<String, String> _getHeaders() {
    final userData = UserData();
    final token = userData.getToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch all addresses
  static Future<List<Address>> fetchAddresses() async {
    try {
      debugPrint('Fetching addresses from: $baseUrl');

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: _getHeaders(),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final List<dynamic> addressesData = jsonData['data'] ?? [];

          List<Address> addresses =
          addressesData
              .map((addressJson) {
            final address = Address.fromJson(addressJson);
            debugPrint(
              'Parsed address: ${address.id} - ${address.label}',
            );
            return address;
          })
              .where(
                (address) => address.isValid,
          ) // Filter out invalid addresses
              .toList();

          debugPrint('Fetched ${addresses.length} valid addresses');
          return addresses;
        } else {
          throw Exception(
            'Failed to fetch addresses: ${jsonData['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
      throw Exception('Failed to fetch addresses: $e');
    }
  }

  // Create new address
  static Future<Address> createAddress(Address address) async {
    try {
      debugPrint('Creating address: ${address.label}');

      // This will now use the new 'lat'/'lng' keys from toCreateJson()
      final body = json.encode(address.toCreateJson());
      debugPrint('Request body: $body');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: _getHeaders(),
        body: body,
      );

      debugPrint('Create response status: ${response.statusCode}');
      debugPrint('Create response body: ${response.body}');

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final addressData = jsonData['data'];
          // fromJson will now correctly parse the new 'location' object
          final newAddress = Address.fromJson(addressData);

          debugPrint('Address created successfully with ID: ${newAddress.id}');
          return newAddress;
        } else {
          throw Exception(
            'Failed to create address: ${jsonData['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'HTTP Error ${response.statusCode}: ${errorData['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('Error creating address: $e');
      throw Exception('Failed to create address: $e');
    }
  }

  // Update existing address
  static Future<Address> updateAddress(
      String addressId,
      Address address,
      ) async {
    try {
      debugPrint('Updating address: $addressId');

      if (addressId.isEmpty) {
        throw Exception('Address ID cannot be empty');
      }

      final url = '$baseUrl/$addressId';
      // This will now use the new 'lat'/'lng' keys from toUpdateJson()
      final body = json.encode(address.toUpdateJson());

      debugPrint('Update URL: $url');
      debugPrint('Update body: $body');

      final response = await http.put(
        Uri.parse(url),
        headers: _getHeaders(),
        body: body,
      );

      debugPrint('Update response status: ${response.statusCode}');
      debugPrint('Update response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final addressData = jsonData['data'];
          // fromJson will now correctly parse the new 'location' object
          final updatedAddress = Address.fromJson(addressData);

          debugPrint('Address updated successfully: ${updatedAddress.id}');
          return updatedAddress;
        } else {
          throw Exception(
            'Failed to update address: ${jsonData['message'] ?? 'Unknown error'}',
          );
        }
      } else if (response.statusCode == 404) {
        throw Exception('Address not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'HTTP Error ${response.statusCode}: ${errorData['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('Error updating address: $e');
      throw Exception('Failed to update address: $e');
    }
  }

  // Delete address
  static Future<bool> deleteAddress(String addressId) async {
    try {
      debugPrint('Deleting address: $addressId');

      if (addressId.isEmpty) {
        throw Exception('Address ID cannot be empty');
      }

      final url = '$baseUrl/$addressId';

      final response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      debugPrint('Delete response status: ${response.statusCode}');
      debugPrint('Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          debugPrint('Address deleted successfully');
          return true;
        } else {
          throw Exception(
            'Failed to delete address: ${jsonData['message'] ?? 'Unknown error'}',
          );
        }
      } else if (response.statusCode == 404) {
        throw Exception('Address not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'HTTP Error ${response.statusCode}: ${errorData['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('Error deleting address: $e');
      throw Exception('Failed to delete address: $e');
    }
  }

  // Get single address by ID
  static Future<Address> getAddressById(String addressId) async {
    try {
      debugPrint('Fetching address: $addressId');

      if (addressId.isEmpty) {
        throw Exception('Address ID cannot be empty');
      }

      final url = '$baseUrl/$addressId';

      final response = await http.get(Uri.parse(url), headers: _getHeaders());

      debugPrint('Get address response status: ${response.statusCode}');
      debugPrint('Get address response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final addressData = jsonData['data'];
          // fromJson will now correctly parse the new 'location' object
          final address = Address.fromJson(addressData);

          debugPrint('Address fetched successfully: ${address.id}');
          return address;
        } else {
          throw Exception(
            'Failed to fetch address: ${jsonData['message'] ?? 'Unknown error'}',
          );
        }
      } else if (response.statusCode == 404) {
        throw Exception('Address not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'HTTP Error ${response.statusCode}: ${errorData['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
      throw Exception('Failed to fetch address: $e');
    }
  }

  // ------------------ Cache helpers ------------------
  static Future<void> saveAddressesToCache(List<Address> addresses) async {
    try {
      final cache = await CacheManager.init();
      // --- MODIFIED: Use toCacheJson() to save in a format fromJson() can read ---
      final data = addresses.map((a) => a.toCacheJson()).toList();
      final expires = DateTime.now().add(Duration(days: 7));
      await cache.save(
        CacheManager.checkoutBoxName,
        'addresses',
        data,
        expires,
      );
    } catch (e) {
      debugPrint('saveAddressesToCache error: $e');
    }
  }

  static Future<List<Address>?> readAddressesFromCache() async {
    try {
      final cache = await CacheManager.init();
      final data = cache.read(CacheManager.checkoutBoxName, 'addresses');
      if (data == null) return null;
      final list = List<dynamic>.from(data as List);
      // This will work because fromJson() can read the 'latitude'/'longitude'
      // keys saved by toCacheJson()
      return list
          .map((m) => Address.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('readAddressesFromCache error: $e');
      return null;
    }
  }
}