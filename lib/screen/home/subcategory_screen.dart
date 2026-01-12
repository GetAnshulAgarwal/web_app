import 'package:eshop/screen/home/product_screen.dart';
import 'package:flutter/material.dart';

import '../../model/home/subcategory.dart';
import '../../services/home/api_service.dart';
import '../../services/navigation_service.dart';

class SubcategoriesScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? selectedSubcategoryId;

  const SubcategoriesScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.selectedSubcategoryId,
  });

  @override
  _SubcategoriesScreenState createState() => _SubcategoriesScreenState();
}

class _SubcategoriesScreenState extends State<SubcategoriesScreen> {
  List<SubCategory> subcategories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSubcategories();
  }

  Future<void> loadSubcategories() async {
    try {
      final loadedSubcategories = await ApiService.getSubCategories(
        widget.categoryId,
      );
      setState(() {
        subcategories = loadedSubcategories;
        isLoading = false;
      });

      // If a specific subcategory was selected, navigate to it
      if (widget.selectedSubcategoryId != null) {
        final selectedSubcategory = subcategories.firstWhere(
          (sub) => sub.id == widget.selectedSubcategoryId,
          orElse: () => subcategories.first,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ProductsScreen(
                    categoryId: widget.categoryId,
                    subcategoryId: selectedSubcategory.id,
                    subcategoryName: selectedSubcategory.name,
                  ),
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading subcategories: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            NavigationService.goBackToHomeScreen();
          },
        ),
        title: Text(widget.categoryName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : GridView.builder(
                padding: EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: subcategories.length,
                itemBuilder: (context, index) {
                  final subcategory = subcategories[index];
                  return SubcategoryCard(
                    subcategory: subcategory,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ProductsScreen(
                                categoryId: widget.categoryId,
                                subcategoryId: subcategory.id,
                                subcategoryName: subcategory.name,
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

class SubcategoryCard extends StatelessWidget {
  final SubCategory subcategory;
  final VoidCallback onTap;

  const SubcategoryCard({
    super.key,
    required this.subcategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child:
                    subcategory.image.isNotEmpty
                        ? ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              // Loading indicator
                              Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[400],
                                ),
                              ),
                              // Image
                              Image.network(
                                ApiService.getImageUrl(
                                  subcategory.image,
                                  'subcategory', // or whatever type is appropriate
                                ),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey[400],
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print(
                                    'Error loading subcategory image: $error',
                                  );
                                  return Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.category,
                                      size: 40,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                        : Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.category,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                        ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subcategory.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subcategory.description.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      subcategory.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
