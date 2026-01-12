// address_form_widget.dart
import 'package:flutter/material.dart';

class AddressFormWidget extends StatelessWidget {
  final TextEditingController houseNoController;
  final TextEditingController areaController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController postalCodeController;
  final TextEditingController locationController;

  const AddressFormWidget({
    Key? key,
    required this.houseNoController,
    required this.areaController,
    required this.cityController,
    required this.stateController,
    required this.postalCodeController,
    required this.locationController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: Colors.brown),
            const SizedBox(width: 8),
            const Text(
              'Delivery Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // House No
        TextFormField(
          controller: houseNoController,
          decoration: InputDecoration(
            labelText: 'House No / Flat No *',
            hintText: 'Enter house or flat number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'House/Flat number is required';
            }
            return null; // IMPORTANT: Return null for valid input
          },
        ),
        const SizedBox(height: 12),

        // Area
        TextFormField(
          controller: areaController,
          decoration: InputDecoration(
            labelText: 'Area / Street *',
            hintText: 'Enter area or street name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Area/Street is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // City
        TextFormField(
          controller: cityController,
          decoration: InputDecoration(
            labelText: 'City *',
            hintText: 'Enter city name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'City is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // State
        TextFormField(
          controller: stateController,
          decoration: InputDecoration(
            labelText: 'State *',
            hintText: 'Enter state name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'State is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Postal Code
        TextFormField(
          controller: postalCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Postal Code *',
            hintText: 'Enter 6-digit postal code',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            counterText: '', // Hide character counter
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Postal code is required';
            }
            if (value.length != 6) {
              return 'Postal code must be 6 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Location Link (Optional)
        TextFormField(
          controller: locationController,
          decoration: InputDecoration(
            labelText: 'Location Link (Optional)',
            hintText: 'Google Maps link',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            prefixIcon: Icon(Icons.link),
          ),
          // No validator - this field is optional
        ),
      ],
    );
  }
}