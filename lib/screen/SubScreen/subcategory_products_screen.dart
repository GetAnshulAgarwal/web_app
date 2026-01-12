/*import 'package:flutter/material.dart';
import '../../model/home/filter_category_model.dart';
import '../../repositories/home_repository.dart';
import '../../widget/home/loading_grid.dart';

class SubcategoryProductsScreen extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const SubcategoryProductsScreen({
    Key? key,
    required this.categoryName,
    required this.categoryId,
  }) : super(key: key);

  @override
  _SubcategoryProductsScreenState createState() =>
      _SubcategoryProductsScreenState();
}

class _SubcategoryProductsScreenState extends State<SubcategoryProductsScreen> {
  List<FilterCategoryModel> products = [];
  bool isLoading = true;
  int currentPage = 1;
  bool hasMoreData = true;
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      if (!isLoading && hasMoreData) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        isLoading = true;
      });

      final newProducts = await HomeRepository.fetchProductsByCategory(
        categoryId: widget.categoryId,
        page: 1,
        limit: 20,
      );

      setState(() {
        products = newProducts;
        currentPage = 1;
        hasMoreData = newProducts.length == 20;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    }
  }

  Future<void> _loadMoreProducts() async {
    try {
      setState(() {
        isLoading = true;
      });

      final newProducts = await HomeRepository.fetchProductsByCategory(
        categoryId: widget.categoryId,
        page: currentPage + 1,
        limit: 20,
      );

      setState(() {
        products.addAll(newProducts);
        currentPage++;
        hasMoreData = newProducts.length == 20;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child:
            isLoading && products.isEmpty
                ? LoadingGrid()
                : GridView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: products.length + (hasMoreData ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == products.length) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final product = products[index];
                    return _buildProductCard(product);
                  },
                ),
      ),
    );
  }

  Widget _buildProductCard(FilterCategoryModel product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to product detail
          print('Product tapped: ${product.itemName}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child:
                      product.itemImageUrl.isNotEmpty
                          ? Image.network(
                            product.itemImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.image_not_supported, size: 50);
                            },
                          )
                          : Icon(Icons.image_not_supported, size: 50),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      product.variant,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Text(
                          '₹${product.salesPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        if (product.mrp > product.salesPrice)
                          Text(
                            '₹${product.mrp.toStringAsFixed(0)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/
