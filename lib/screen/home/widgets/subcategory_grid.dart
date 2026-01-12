import 'package:flutter/material.dart';
import '../../../model/home/subcategory.dart';
import 'subcategory_item.dart';

class SubcategoryGrid extends StatelessWidget {
  final List<SubCategory> subcategories;
  final Function(SubCategory) onSubcategoryTap;
  final double? imageSize;
  final double? fontSize;
  final int maxItemsToShow;
  final EdgeInsetsGeometry? padding;

  const SubcategoryGrid({
    super.key,
    required this.subcategories,
    required this.onSubcategoryTap,
    this.imageSize = 80,
    this.fontSize = 12,
    this.maxItemsToShow = 8,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (subcategories.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, color: Colors.grey, size: 32),
              SizedBox(height: 8),
              Text(
                'No subcategories available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final itemsToShow = subcategories.take(maxItemsToShow).toList();
    List<Widget> rows = [];

    for (int i = 0; i < itemsToShow.length; i += 4) {
      List<Widget> rowItems = [];

      for (int j = i; j < i + 4 && j < itemsToShow.length; j++) {
        final subcategory = itemsToShow[j];
        rowItems.add(
          Expanded(
            child: Container(
              alignment: Alignment.center, // ← Center alignment
              child: SubcategoryItem(
                subcategory: subcategory,
                onTap: () => onSubcategoryTap(subcategory),
                imageSize: imageSize,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      }

      // Fill remaining spaces in the row if needed
      while (rowItems.length < 4) {
        rowItems.add(Expanded(child: SizedBox()));
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // ← Changed to spaceEvenly
          crossAxisAlignment: CrossAxisAlignment.start, // ← Added for vertical alignment
          children: rowItems,
        ),
      );

      // Add spacing between rows
      if (i + 4 < itemsToShow.length) {
        rows.add(SizedBox(height: 20)); // ← Increased spacing
      }
    }

    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(), // ← Prevents independent scrolling
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8), // ← Added default padding
        child: Column(
          children: rows,
        ),
      ),
    );
  }
}