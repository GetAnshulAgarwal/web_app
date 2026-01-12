// Updated AddressCard with selection mode support
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../model/Address/address_model.dart';
import '../../utils/constants.dart';

/// {@template address_card}
/// A card widget to display a single address.
///
/// This widget has two modes, controlled by [isSelectionMode]:
/// 1. **Display/Manage Mode (!isSelectionMode):** Shows action buttons for
///    editing, deleting, and setting an address as default.
/// 2. **Selection Mode (isSelectionMode):** Acts as a tappable button
///    (via [onTap]) to select the address, hiding the action buttons
///    and showing a selection indicator.
/// {@endtemplate}
class AddressCard extends StatelessWidget {
  /// {@macro address_card}
  const AddressCard({
    Key? key,
    required this.address,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
    this.onTap,
    this.isSelectionMode = false,
  }) : super(key: key);

  /// The address data model to display.
  final Address address;

  /// Callback triggered when the edit action is tapped.
  /// Only shown if [isSelectionMode] is false.
  final VoidCallback? onEdit;

  /// Callback triggered when the delete action is tapped.
  /// Only shown if [isSelectionMode] is false.
  final VoidCallback? onDelete;

  /// Callback triggered when the "set default" action is tapped.
  /// Only shown if [isSelectionMode] is false and [address.isDefault] is false.
  final VoidCallback? onSetDefault;

  /// Callback triggered when the card itself is tapped.
  /// Only active when [isSelectionMode] is true.
  final VoidCallback? onTap;

  /// Toggles the widget between display mode and selection mode.
  /// Defaults to false (display mode).
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelectionMode ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelectionMode
              ? Border.all(
            color: AppColors.primaryGreen.withOpacity(0.5),
            width: 2,
          )
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map thumbnail
              _buildMapThumbnail(),
              const SizedBox(width: 16),
              // Address details
              Expanded(child: _buildAddressDetails(context)),
              // Actions or selection indicator
              if (!isSelectionMode)
                _buildActions(context)
              else
                _buildSelectionIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.hardEdge,
      child: address.latitude != null && address.longitude != null
          ? FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(address.latitude!, address.longitude!),
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none, // Disable all interactions
          ),
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
                width: 30,
                height: 30,
                point: LatLng(address.latitude!, address.longitude!),
                child: const Icon(
                  Icons.location_pin,
                  color: AppColors.errorRed,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      )
          : Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.location_pin,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildAddressDetails(BuildContext context) {
    // Using Theme.of(context) is better for scalability,
    // but const TextStyles are better for performance if styles are fixed.
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Address type and label
        Row(
          children: [
            Icon(_getAddressIcon(), size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                address.label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 16,
                ) ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
              ),
            ),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Full address
        Text(
          address.fullAddress,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            height: 1.4,
          ) ??
              TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Selection mode hint
        if (isSelectionMode) ...[
          const SizedBox(height: 8),
          const Text(
            'Tap to use this address',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!address.isDefault) ...[
          _ActionButton(
            icon: Icons.check_circle_outline,
            backgroundColor: AppColors.lightGreen,
            iconColor: AppColors.primaryGreen,
            onTap: onSetDefault,
          ),
          const SizedBox(width: 8),
        ],
        _ActionButton(
          icon: Icons.edit,
          backgroundColor: Colors.blue.shade50,
          iconColor: Colors.blue.shade600,
          onTap: onEdit,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.delete_outline,
          backgroundColor: Colors.red.shade50,
          iconColor: Colors.red.shade600,
          onTap: onDelete,
        ),
      ],
    );
  }

  Widget _buildSelectionIndicator() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.primaryGreen,
      ),
    );
  }

  IconData _getAddressIcon() {
    switch (address.addressType) {
      case AddressType.home:
        return Icons.home;
      case AddressType.work:
        return Icons.work;
      case AddressType.other:
      default:
        return Icons.location_on;
    }
  }
}

/// A private helper widget for the action buttons in [AddressCard].
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    Key? key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  }) : super(key: key);

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}