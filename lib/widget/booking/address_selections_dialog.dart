import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../model/Address/address_model.dart';

class AddressSelectionDialog extends StatefulWidget {
  final LatLng currentLocation;
  final String currentAddress;
  final String currentArea;
  final String currentCity;
  final String currentState;
  final String currentPostalCode;
  final List<Address> savedAddresses;
  final Address? selectedAddress;

  const AddressSelectionDialog({
    Key? key,
    required this.currentLocation,
    required this.currentAddress,
    required this.currentArea,
    required this.currentCity,
    required this.currentState,
    required this.currentPostalCode,
    this.savedAddresses = const [],
    this.selectedAddress,
  }) : super(key: key);

  @override
  State<AddressSelectionDialog> createState() => _AddressSelectionDialogState();
}

class _AddressSelectionDialogState extends State<AddressSelectionDialog> {
  Address? _selectedAddress;
  bool _showAddressForm = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.selectedAddress;

    // If no saved addresses, show form by default
    if (widget.savedAddresses.isEmpty) {
      _showAddressForm = true;
      _fillFormWithCurrentLocation();
    }
  }

  void _fillFormWithCurrentLocation() {
    _streetController.text = widget.currentAddress;
    _areaController.text = widget.currentArea;
    _cityController.text = widget.currentCity;
    _stateController.text = widget.currentState;
    _postalCodeController.text = widget.currentPostalCode;
    _labelController.text = 'Current Location';
    _isDefault = false;
  }

  String _fillFormWithAddress(Address address) {
    _streetController.text = address.street;
    _areaController.text = address.area;
    _cityController.text = address.city;
    _stateController.text = address.state;
    _postalCodeController.text = address.postalCode;
    _labelController.text = address.label;
    _isDefault = address.isDefault;
    return address.id;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove duplicates from saved addresses
    final uniqueSavedAddresses = widget.savedAddresses.toSet().toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.brown.shade800),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Select Pickup Address',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      insetPadding: const EdgeInsets.all(24.0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saved Addresses Dropdown (if available)
            if (uniqueSavedAddresses.isNotEmpty) ...[
              const Text(
                'Saved Addresses',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Address>(
                    isExpanded: true,
                    value: _selectedAddress,
                    hint: const Text('Select a saved address'),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.brown.shade800,
                    ),
                    items: [
                      ...uniqueSavedAddresses.map((address) {
                        return DropdownMenuItem<Address>(
                          value: address,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      address.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (address.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${address.street}, ${address.area}, ${address.city}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      DropdownMenuItem<Address>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.brown.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add New Address',
                              style: TextStyle(
                                color: Colors.brown.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        if (value != null) {
                          _selectedAddress = value;
                          _fillFormWithAddress(value);
                          _showAddressForm = false;
                        } else {
                          // Add new address
                          _selectedAddress = null;
                          _fillFormWithCurrentLocation();
                          _showAddressForm = true;
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Option to use current location
              ListTile(
                leading: Icon(Icons.my_location, color: Colors.blue.shade700),
                title: const Text('Use Current Location'),
                subtitle: Text(
                  widget.currentAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context, {
                    'isCurrentLocation': true,
                    'street': widget.currentAddress,
                    'area': widget.currentArea,
                    'city': widget.currentCity,
                    'state': widget.currentState,
                    'postalCode': widget.currentPostalCode,
                    'coordinates': [
                      widget.currentLocation.latitude,
                      widget.currentLocation.longitude,
                    ],
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 24),
            ],

            // Address Form (shown when adding new or no saved addresses)
            if (_showAddressForm) ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Address Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g., Home, Office)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Label is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Street is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Area / Locality',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Area is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'City is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'State is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Postal Code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Postal Code is required';
                        }
                        if (value.length < 5) {
                          return 'Invalid Postal Code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Set as default address'),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // ===== FIX: PROPER NULL CHECK =====
            // If using saved address (not showing form and address is selected)
            if (_selectedAddress != null && !_showAddressForm) {
              print('Selected Address ID: ${_selectedAddress!.id}');

              Navigator.pop(context, {
                'addressId': _selectedAddress!.id,
                'street': _selectedAddress!.street,
                'area': _selectedAddress!.area,
                'city': _selectedAddress!.city,
                'state': _selectedAddress!.state,
                'postalCode': _selectedAddress!.postalCode,
                'label': _selectedAddress!.label,
                'isDefault': _selectedAddress!.isDefault,
                'coordinates':
                _selectedAddress!.latitude != null &&
                    _selectedAddress!.longitude != null
                    ? [
                  _selectedAddress!.latitude!,
                  _selectedAddress!.longitude!,
                ]
                    : [
                  widget.currentLocation.latitude,
                  widget.currentLocation.longitude,
                ],
              });
            }
            // If adding new address (form is shown and validated)
            else if (_showAddressForm) {
              if (_formKey.currentState?.validate() ?? false) {
                print('Adding new address from form');

                Navigator.pop(context, {
                  'isNewAddress': true,
                  'street': _streetController.text.trim(),
                  'area': _areaController.text.trim(),
                  'city': _cityController.text.trim(),
                  'state': _stateController.text.trim(),
                  'postalCode': _postalCodeController.text.trim(),
                  'label': _labelController.text.trim(),
                  'isDefault': _isDefault,
                  'country': 'India',
                  'coordinates': [
                    widget.currentLocation.latitude,
                    widget.currentLocation.longitude,
                  ],
                });
              } else {
                // Show error if form validation failed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
            // If no address selected and form not shown (edge case)
            else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an address or add a new one'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB21E1E),
          ),
          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}