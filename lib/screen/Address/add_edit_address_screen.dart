import 'dart:async'; // Required for Timer
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../utils/constants.dart';
import '../../model/Address/address_model.dart';
import '../../services/navigation_service.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Address? address; // Null for adding new address, non-null for editing

  const AddEditAddressScreen({Key? key, this.address}) : super(key: key);

  @override
  _AddEditAddressScreenState createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _streetController;
  late TextEditingController _areaController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;

  AddressType _selectedType = AddressType.home;
  bool _isDefault = false;
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  // --- NEW: Logic variables for Forward Geocoding ---
  bool _isUpdatingAddressFromMap = false; // Prevents infinite loops
  Timer? _debounce; // Delays the API call while typing
  // -------------------------------------------------

  // Default coordinates (New Delhi)
  double _latitude = 28.7041;
  double _longitude = 77.1025;

  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeControllers();

    // --- NEW: Add listeners to text fields to update map ---
    _streetController.addListener(_onAddressFieldChanged);
    _areaController.addListener(_onAddressFieldChanged);
    _cityController.addListener(_onAddressFieldChanged);
    _stateController.addListener(_onAddressFieldChanged);
    _postalCodeController.addListener(_onAddressFieldChanged);
    _countryController.addListener(_onAddressFieldChanged);
    // ------------------------------------------------------

    _getCurrentLocation();
  }

  void _initializeControllers() {
    if (widget.address != null) {
      // Editing existing address
      final address = widget.address!;
      _labelController = TextEditingController(text: address.label);
      _streetController = TextEditingController(text: address.street);
      _areaController = TextEditingController(text: address.area);
      _cityController = TextEditingController(text: address.city);
      _stateController = TextEditingController(text: address.state);
      _postalCodeController = TextEditingController(text: address.postalCode);
      _countryController = TextEditingController(text: address.country);
      _selectedType = address.addressType;
      _isDefault = address.isDefault;
      _latitude = address.latitude ?? _latitude;
      _longitude = address.longitude ?? _longitude;
    } else {
      // Adding new address
      _labelController = TextEditingController();
      _streetController = TextEditingController();
      _areaController = TextEditingController();
      _cityController = TextEditingController();
      _stateController = TextEditingController();
      _postalCodeController = TextEditingController();
      _countryController = TextEditingController(text: 'India');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancel timer
    _labelController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // --- NEW: Logic to detect typing and update map ---
  void _onAddressFieldChanged() {
    // 1. If the text change was caused by the map (Reverse Geocode), ignore it.
    if (_isUpdatingAddressFromMap) return;

    // 2. Cancel previous timer if user is still typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 3. Set a new timer (wait 1 second after typing stops)
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _updateMapFromText();
    });
  }

  Future<void> _updateMapFromText() async {
    // Construct a query string from available fields
    String query = '';

    if (_streetController.text.isNotEmpty) query += '${_streetController.text}, ';
    if (_areaController.text.isNotEmpty) query += '${_areaController.text}, ';
    if (_cityController.text.isNotEmpty) query += '${_cityController.text}, ';
    if (_stateController.text.isNotEmpty) query += '${_stateController.text}, ';
    if (_postalCodeController.text.isNotEmpty) query += '${_postalCodeController.text}, ';
    if (_countryController.text.isNotEmpty) query += _countryController.text;

    // Clean up query
    query = query.trim();
    if (query.endsWith(',')) query = query.substring(0, query.length - 1);

    // Don't search if query is too short
    if (query.isEmpty || query.length < 5) return;

    try {
      // Perform Forward Geocoding (Text -> LatLng)
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final loc = locations.first;

        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
        });

        // Move map to new coordinates
        _mapController.move(LatLng(_latitude, _longitude), 15.0);
      }
    } catch (e) {
      // Silently fail if address not found while typing to avoid annoying popups
      debugPrint('Forward geocoding failed: $e');
    }
  }
  // --------------------------------------------------

  Future<void> _getCurrentLocation() async {
    if (widget.address != null) return; // Don't get location when editing

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      _mapController.move(LatLng(_latitude, _longitude), 15.0);
      await _reverseGeocode(_latitude, _longitude);
    } catch (e) {
      _showLocationError('Failed to get current location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        // --- UPDATED: Set flag to prevent loop ---
        _isUpdatingAddressFromMap = true;

        setState(() {
          _streetController.text = placemark.street ?? '';
          _areaController.text = placemark.subLocality ?? '';
          _cityController.text = placemark.locality ?? '';
          _stateController.text = placemark.administrativeArea ?? '';
          _postalCodeController.text = placemark.postalCode ?? '';
          _countryController.text = placemark.country ?? 'India';
        });

        // Reset flag after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdatingAddressFromMap = false;
        });
        // -----------------------------------------
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        NavigationService.goBackToHomeScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Address' : 'Add New Address',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: NavigationService.goBackToHomeScreen,
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMapSection(),
                const SizedBox(height: 24),
                _buildAddressTypeSection(),
                const SizedBox(height: 24),
                _buildFormFields(),
                const SizedBox(height: 24),
                _buildDefaultCheckbox(),
                const SizedBox(height: 32),
                _buildSaveButton(isEditing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Location on Map',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_isLoadingLocation)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_latitude, _longitude),
                  initialZoom: 15,
                  onTap: (tapPosition, latLng) {
                    setState(() {
                      _latitude = latLng.latitude;
                      _longitude = latLng.longitude;
                    });
                    _reverseGeocode(_latitude, _longitude);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 50,
                        height: 50,
                        point: LatLng(_latitude, _longitude),
                        child: const Icon(
                          Icons.location_pin,
                          color: AppColors.errorRed,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 12,
                right: 12,
                child: FloatingActionButton.small(
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryGreen,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap map to select location, or type address below to auto-update.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAddressTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTypeButton(AddressType.home, 'Home', Icons.home_rounded),
            const SizedBox(width: 12),
            _buildTypeButton(AddressType.work, 'Work', Icons.work_rounded),
            const SizedBox(width: 12),
            _buildTypeButton(
              AddressType.other,
              'Other',
              Icons.location_on_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(AddressType type, String label, IconData icon) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type != AddressType.other) {
              _labelController.text = label;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : AppColors.lightGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primaryGreen,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _labelController,
          label: 'Address Label',
          hint: 'e.g., Home, Office, etc.',
          icon: Icons.label_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter an address label';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _streetController,
          label: 'Street Address',
          hint: 'House/Flat number, Street name',
          icon: Icons.home_outlined,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter street address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _areaController,
          label: 'Area/Locality',
          hint: 'Area, Sector, Locality',
          icon: Icons.location_city_outlined,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter area/locality';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _cityController,
                label: 'City',
                hint: 'City name',
                icon: Icons.location_city,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _postalCodeController,
                label: 'PIN Code',
                hint: '123456',
                icon: Icons.markunread_mailbox_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  if (value.length != 6) {
                    return 'Invalid PIN';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _stateController,
                label: 'State',
                hint: 'State name',
                icon: Icons.map_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _countryController,
                label: 'Country',
                hint: 'Country name',
                icon: Icons.public,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDefaultCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isDefault,
            onChanged: (value) {
              setState(() {
                _isDefault = value ?? false;
              });
            },
            activeColor: AppColors.primaryGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set as Default Address',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'This address will be used as your primary delivery location',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          isEditing ? 'UPDATE ADDRESS' : 'SAVE ADDRESS',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_latitude == 28.7041 && _longitude == 77.1025) {
      // This is still the default (Delhi) and likely hasn't been set by GPS or map interaction
      // This is a safety check; ideally the user must interact with the map.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map or use GPS to confirm location.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final addressData = Address(
        id: widget.address?.id ?? '', // Don't generate temporary ID
        label: _labelController.text.trim(),
        street: _streetController.text.trim(),
        area: _areaController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        isDefault: _isDefault,
        latitude: _latitude,
        longitude: _longitude,
        createdAt: widget.address?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Return the address data to the previous screen
      if (!mounted) return;
      Navigator.pop(context, addressData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving address: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}