
import 'package:flutter/material.dart';

import '../../../Animation/bouncing_dots.dart';
import '../../../model/home/category.dart';
import '../../../services/home/api_service.dart';
import '../../../widget/home/optimized_network.dart';
import '../../home_screen.dart';

class CategorySection extends StatefulWidget {
  final Category category;
  final Function(dynamic) onSubcategoryTap;

  const CategorySection({
    super.key,
    required this.category,
    required this.onSubcategoryTap,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  late Future<List<dynamic>> _subcategoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  void _loadSubcategories() {
    _subcategoriesFuture =
        ApiService.getSubCategories(widget.category.id)
            .timeout(const Duration(seconds: 10))
            .catchError((e) {
          debugPrint(
              'Error loading subcategories for ${widget.category.name}: $e');
          return <dynamic>[];
        });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.category.name.toLowerCase(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<dynamic>>(
            future: _subcategoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingGrid();
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildSubcategoryGrid(snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryGrid(List<dynamic> subcategories) {
    const itemsPerRow = 4;
    final rows = (subcategories.length / itemsPerRow).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        final startIndex = rowIndex * itemsPerRow;
        final endIndex =
        (startIndex + itemsPerRow).clamp(0, subcategories.length);
        final rowItems = subcategories.sublist(startIndex, endIndex);

        return Container(
          margin: EdgeInsets.only(bottom: rowIndex < rows - 1 ? 16 : 0),
          height: 160,
          child: Row(
            children: [
              ...rowItems.asMap().entries.map((entry) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: entry.key < rowItems.length - 1 ? 12 : 0),
                    child: _buildSubcategoryItem(entry.value),
                  ),
                );
              }),
              ...List.generate(
                  itemsPerRow - rowItems.length, (_) => const Expanded(child: SizedBox())),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSubcategoryItem(dynamic subcategory) {
    return GestureDetector(
      onTap: () {
        try {
          widget.onSubcategoryTap(subcategory);
        } catch (e) {
          debugPrint('Error in subcategory tap: $e');
        }
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildSubcategoryImage(subcategory),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              subcategory.name?.toLowerCase() ?? 'Unknown',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryImage(dynamic subcategory) {
    final imageUrl = subcategory.image;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderIcon();
    }

    return OptimizedNetworkImage(
      imageUrl: imageUrl,
      imageType: 'subcategory',
      width: double.infinity,
      height: 80,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: const Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.circle, size: 20, color: Colors.grey),
            Icon(Icons.circle, size: 14, color: Colors.grey),
            Icon(Icons.circle, size: 8, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return const SizedBox(
      height: 160,
      child: Center(
        child: BouncingDotsIndicator(color: Colors.grey, size: 5.0),
      ),
    );
  }
}