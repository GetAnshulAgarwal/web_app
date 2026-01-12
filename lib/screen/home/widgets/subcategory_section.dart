import 'package:flutter/material.dart';

import '../../../model/home/category.dart';
import '../../../model/home/subcategory.dart';
import '../../../services/home/api_service.dart';
import 'subcategory_grid.dart';

class SubcategorySection extends StatefulWidget {
  final Category category;
  final Function(SubCategory) onSubcategoryTap;
  final int maxItemsToShow;
  final bool showTitle;
  final EdgeInsetsGeometry? padding;

  const SubcategorySection({
    Key? key,
    required this.category,
    required this.onSubcategoryTap,
    this.maxItemsToShow = 8,
    this.showTitle = true,
    this.padding,
  }) : super(key: key);

  @override
  _SubcategorySectionState createState() => _SubcategorySectionState();
}

class _SubcategorySectionState extends State<SubcategorySection>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  Widget _buildSubcategorySkeleton() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) => _buildSkeletonItem()),
        ),
      ],
    );
  }

  Widget _buildSkeletonItem() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 50,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.category.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(height: 12),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<List<SubCategory>>(
              future: ApiService.getSubCategories(widget.category.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSubcategorySkeleton();
                }

                if (snapshot.hasError) {
                  return Container(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.orange),
                          SizedBox(height: 8),
                          Text(
                            'Unable to load subcategories',
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

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, color: Colors.grey),
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

                return SubcategoryGrid(
                  subcategories: snapshot.data!,
                  onSubcategoryTap: widget.onSubcategoryTap,
                  maxItemsToShow: widget.maxItemsToShow,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}