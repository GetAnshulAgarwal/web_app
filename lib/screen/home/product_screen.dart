import 'package:eshop/screen/home/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/home/deck.dart';
import '../../model/home/subsubcategory.dart';
import '../../model/home/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/home/api_service.dart';
import '../../services/stock_service.dart';
import '../../services/navigation_service.dart';
import '../../widget/product_add_button.dart';
import '../cart_screen.dart';

class ProductsScreen extends StatefulWidget {
  final String categoryId;
  final String subcategoryId;
  final String subcategoryName;

  const ProductsScreen({
    super.key,
    required this.categoryId,
    required this.subcategoryId,
    required this.subcategoryName,
  });

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<SubSubCategory> subsubcategories = [];
  List<Deck> decks = [];
  List<Product> _rawAllProducts = [];
  Map<String, List<Product>> subsubcategoryProducts = {};
  bool isUsingDecks = false;
  bool isLoading = true;
  String selectedFilter = 'All';
  List<String> availableFilters = ['All'];
  Map<String, String> filterImageMap = {};
  Map<String, String> filterImageTypeMap = {};
  String? errorMessage;

  void _sortProductsByStock(List<Product> products) {
    products.sort((a, b) {
      bool aInStock = a.stock > 0;
      bool bInStock = b.stock > 0;
      if (aInStock && !bInStock) return -1;
      if (!aInStock && bInStock) return 1;
      return 0;
    });
  }

  List<Product> _groupProducts(List<Product> rawList) {
    if (rawList.isEmpty) return [];
    Map<String, List<Product>> groupedMap = {};
    List<Product> singles = [];
    for (var product in rawList) {
      if (product.itemGroup == 'Variant' && product.parentItemId != null) {
        if (!groupedMap.containsKey(product.parentItemId)) {
          groupedMap[product.parentItemId!] = [];
        }
        groupedMap[product.parentItemId!]!.add(product);
      } else {
        singles.add(product);
      }
    }
    List<Product> representativeProducts = [];
    groupedMap.forEach((parentId, variants) {
      if (variants.isNotEmpty) {
        variants.sort((a, b) => a.salesPrice.compareTo(b.salesPrice));
        Product mainFace = variants.first;
        Product productWithVariants = mainFace.copyWith(variants: variants);
        representativeProducts.add(productWithVariants);
      }
    });
    final combinedList = [...singles, ...representativeProducts];
    _sortProductsByStock(combinedList);
    return combinedList;
  }

  Future<void> _syncRealTimeStockAndSort(List<Product> productsToSync) async {
    if (productsToSync.isEmpty) return;
    int chunkSize = 6;
    for (int i = 0; i < productsToSync.length; i += chunkSize) {
      if (!mounted) return;
      int end = (i + chunkSize < productsToSync.length) ? i + chunkSize : productsToSync.length;
      List<Product> batch = productsToSync.sublist(i, end);
      List<Future<void>> futures = [];
      for (int j = 0; j < batch.length; j++) {
        futures.add(_updateSingleProductStock(productsToSync, i + j));
      }
      await Future.wait(futures);
    }
  }

  Future<void> _updateSingleProductStock(List<Product> listReference, int index) async {
    try {
      final product = listReference[index];
      final stockResponse = await StockService.getItemStock(product.id);
      if (stockResponse != null && mounted) {
        listReference[index] = product.copyWith(stock: stockResponse.currentStock);
      }
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();
    loadSubSubCategoriesAndProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).loadCart();
    });
  }

  Future<void> loadSubSubCategoriesAndProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      isUsingDecks = false;
    });
    try {
      List<SubSubCategory> loadedSubSubCategories = [];
      try {
        loadedSubSubCategories = await ApiService.getSubSubCategories(
          widget.categoryId,
          widget.subcategoryId,
        ).timeout(const Duration(seconds: 30));
      } catch (e) {}
      if (loadedSubSubCategories.isEmpty) {
        await _loadDecksData();
        return;
      }
      await _loadSubSubCategoriesData(loadedSubSubCategories);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _loadDecksData() async {
    try {
      final loadedDecks = await ApiService.getDecksView(
        widget.categoryId,
        widget.subcategoryId,
      );
      for (var deck in loadedDecks) {
        _sortProductsByStock(deck.items);
      }
      List<Product> flatProducts = loadedDecks.expand((deck) => deck.items).toList();
      _sortProductsByStock(flatProducts);
      setState(() {
        decks = loadedDecks;
        _rawAllProducts = flatProducts;
        availableFilters = ['All'] + loadedDecks.map((deck) => deck.name).toList();
        isUsingDecks = true;
        _setupFilterImages(loadedDecks);
        isLoading = false;
      });
      _syncDecksInBackground(loadedDecks);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'No data available.';
      });
    }
  }

  Future<void> _syncDecksInBackground(List<Deck> loadedDecks) async {
    for (var deck in loadedDecks) {
      if (!mounted) return;
      await _syncRealTimeStockAndSort(deck.items);
      if (mounted) {
        setState(() {
          _rawAllProducts = loadedDecks.expand((d) => d.items).toList();
          _sortProductsByStock(_rawAllProducts);
        });
      }
    }
  }

  Future<void> _loadSubSubCategoriesData(List<SubSubCategory> loadedSubSubCategories) async {
    List<Product> allLoadedProducts = [];
    Map<String, List<Product>> loadedSubsubcategoryProducts = {};
    for (final subsubcategory in loadedSubSubCategories) {
      try {
        final products = await ApiService.getItemsForSubSubCategory(
          widget.categoryId,
          widget.subcategoryId,
          subsubcategory.id,
        );
        _sortProductsByStock(products);
        loadedSubsubcategoryProducts[subsubcategory.id] = products;
        allLoadedProducts.addAll(products);
      } catch (e) {
        loadedSubsubcategoryProducts[subsubcategory.id] = [];
      }
    }
    _sortProductsByStock(allLoadedProducts);
    setState(() {
      subsubcategories = loadedSubSubCategories;
      _rawAllProducts = allLoadedProducts;
      subsubcategoryProducts = loadedSubsubcategoryProducts;
      availableFilters = ['All'] + loadedSubSubCategories.map((ssc) => ssc.name).toList();
      filterImageMap = {'All': ''};
      filterImageTypeMap = {'All': 'icon'};
      for (final subsubcategory in loadedSubSubCategories) {
        String imageUrl = '';
        String imageType = 'icon';
        if (subsubcategory.image.isNotEmpty && subsubcategory.image != 'null') {
          imageUrl = subsubcategory.image;
          imageType = 'subsubcategory';
        } else {
          final products = loadedSubsubcategoryProducts[subsubcategory.id] ?? [];
          for (final product in products) {
            if (product.itemImages.isNotEmpty && product.itemImages.first.isNotEmpty) {
              imageUrl = product.itemImages.first;
              imageType = 'item';
              break;
            }
          }
        }
        filterImageMap[subsubcategory.name] = imageUrl;
        filterImageTypeMap[subsubcategory.name] = imageType;
      }
      isUsingDecks = false;
      isLoading = false;
    });
    _syncSubSubCategoriesInBackground(loadedSubSubCategories, loadedSubsubcategoryProducts);
  }

  Future<void> _syncSubSubCategoriesInBackground(List<SubSubCategory> cats, Map<String, List<Product>> productMap) async {
    for (final subcat in cats) {
      if (!mounted) return;
      final products = productMap[subcat.id];
      if (products != null && products.isNotEmpty) {
        await _syncRealTimeStockAndSort(products);
        if (mounted) {
          setState(() {
            _rawAllProducts = productMap.values.expand((x) => x).toList();
            _sortProductsByStock(_rawAllProducts);
          });
        }
      }
    }
  }

  void _setupFilterImages(List<Deck> loadedDecks) {
    filterImageMap = {'All': ''};
    filterImageTypeMap = {'All': 'icon'};
    for (final deck in loadedDecks) {
      String imageUrl = '';
      String imageType = 'icon';
      if (deck.image.isNotEmpty && deck.image != 'null') {
        imageUrl = deck.image;
        imageType = 'deck';
      } else if (deck.items.isNotEmpty) {
        for (final item in deck.items) {
          if (item.itemImages.isNotEmpty && item.itemImages.first.isNotEmpty) {
            imageUrl = item.itemImages.first;
            imageType = 'item';
            break;
          }
        }
      }
      filterImageMap[deck.name] = imageUrl;
      filterImageTypeMap[deck.name] = imageType;
    }
  }

  List<Product> getFilteredProducts() {
    List<Product> rawListToDisplay;
    if (selectedFilter == 'All') {
      rawListToDisplay = _rawAllProducts;
    } else if (isUsingDecks) {
      final selectedDeck = decks.firstWhere((deck) => deck.name == selectedFilter, orElse: () => Deck(id: '', name: '', items: [], image: '', description: ''));
      rawListToDisplay = selectedDeck.items;
    } else {
      final selectedSubSubCategory = subsubcategories.firstWhere((ssc) => ssc.name == selectedFilter, orElse: () => SubSubCategory(id: '', name: '', description: '', image: ''));
      rawListToDisplay = subsubcategoryProducts[selectedSubSubCategory.id] ?? [];
    }
    return _groupProducts(rawListToDisplay);
  }

  Widget _buildCategoryIcon(String filter, bool isSelected, bool isWeb) {
    double size = isWeb ? 45 : 35;
    if (filter == 'All') {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withValues(alpha: 0.2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.grid_view, color: isSelected ? Colors.green : Colors.grey[600], size: size * 0.5),
      );
    }
    final imageUrl = filterImageMap[filter] ?? '';
    final imageType = filterImageTypeMap[filter] ?? 'icon';
    if (imageUrl.isNotEmpty) {
      List<String> possibleUrls = _generateImageUrls(imageUrl, imageType);
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.green : Colors.grey[300]!, width: isSelected ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImageWithFallbacks(possibleUrls, isSelected, 0, filter, size),
        ),
      );
    }
    // Fixed assignment_return spelling here
    return _buildFallbackIcon(filter, isSelected, size);
  }

  List<String> _generateImageUrls(String imageUrl, String imageType) {
    if (imageUrl.startsWith('http')) return [imageUrl];
    return ApiService.generateImageUrlsForType(imageUrl, imageType);
  }

  Widget _buildImageWithFallbacks(List<String> urls, bool isSelected, int urlIndex, String filterName, double size) {
    if (urlIndex >= urls.length) return _buildFallbackIcon(filterName, isSelected, size);
    return Image.network(
      urls[urlIndex],
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildImageWithFallbacks(urls, isSelected, urlIndex + 1, filterName, size),
    );
  }

  Widget _buildFallbackIcon(String filter, bool isSelected, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withValues(alpha: 0.2) : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.category, color: isSelected ? Colors.green : Colors.grey[600], size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth > 900;
    final double sidebarWidth = isWeb ? 260 : 85;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        NavigationService.goBackToHomeScreen();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => NavigationService.goBackToHomeScreen(),
          ),
          title: Text(widget.subcategoryName),
          centerTitle: isWeb,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return Padding(
                  padding: EdgeInsets.only(right: isWeb ? 24 : 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                      ),
                      if (cartProvider.totalItemsInCart > 0)
                        Positioned(
                          right: 5, top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text('${cartProvider.totalItemsInCart}', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.grey[50],
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 50,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey[50],
                    child: Align(
                      alignment: isWeb ? Alignment.centerLeft : Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isWeb ? 16 : 0),
                        child: Text('CATEGORIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.1)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: availableFilters.length,
                      itemBuilder: (context, index) {
                        final filter = availableFilters[index];
                        final isSelected = selectedFilter == filter;
                        return GestureDetector(
                          onTap: () => setState(() => selectedFilter = filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: isWeb ? 16 : 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green.withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Colors.green.withValues(alpha: 0.5) : Colors.transparent),
                            ),
                            child: isWeb
                                ? Row(
                              children: [
                                _buildCategoryIcon(filter, isSelected, isWeb),
                                const SizedBox(width: 12),
                                Expanded(child: Text(filter, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.green[700] : Colors.black87))),
                              ],
                            )
                                : Column(
                              children: [
                                _buildCategoryIcon(filter, isSelected, isWeb),
                                const SizedBox(height: 6),
                                Text(filter, style: TextStyle(fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 2),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: getFilteredProducts().isEmpty
                      ? const Center(child: Text("No products found"))
                      : GridView.builder(
                    padding: EdgeInsets.all(isWeb ? 32 : 16),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isWeb ? 280 : 200,
                      mainAxisSpacing: isWeb ? 24 : 16,
                      crossAxisSpacing: isWeb ? 24 : 16,
                      // High childAspectRatio to prevent bottom overflow on Web
                      childAspectRatio: isWeb ? 0.75 : 0.65,
                    ),
                    itemCount: getFilteredProducts().length,
                    itemBuilder: (context, index) {
                      return SeparatedProductCard(
                        product: getFilteredProducts()[index],
                        categoryId: widget.categoryId,
                        subcategoryId: widget.subcategoryId,
                        isWeb: isWeb,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeparatedProductCard extends StatefulWidget {
  final Product product;
  final String? categoryId;
  final String? subcategoryId;
  final bool isWeb;

  const SeparatedProductCard({
    super.key,
    required this.product,
    this.categoryId,
    this.subcategoryId,
    this.isWeb = false,
  });

  @override
  _SeparatedProductCardState createState() => _SeparatedProductCardState();
}

class _SeparatedProductCardState extends State<SeparatedProductCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool hasValidImage = widget.product.itemImages.isNotEmpty &&
        widget.product.itemImages.first.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(
            product: widget.product,
            categoryId: widget.categoryId,
            subcategoryId: widget.subcategoryId,
          )));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isHovered ? (Matrix4.identity()..translate(0, -8, 0)) : Matrix4.identity(),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isHovered ? Colors.green.withValues(alpha: 0.3) : Colors.grey[200]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isHovered ? 0.1 : 0.05),
                  spreadRadius: 1, blurRadius: isHovered ? 12 : 4,
                  offset: const Offset(0, 4)
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use Expanded to allow the image to fill space without causing overflow
              Expanded(
                child: Center(
                  child: hasValidImage
                      ? Image.network(
                    ApiService.getImageUrl(widget.product.itemImages.first, 'item'),
                    fit: BoxFit.contain,
                  )
                      : const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.product.displayName,
                style: TextStyle(
                    fontSize: widget.isWeb ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (widget.product.discountPercentage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 0.5)
                  ),
                  child: Text('${widget.product.discountPercentage.toInt()}% OFF', style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹${widget.product.salesPrice.toInt()}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: widget.isWeb ? 17 : 15, color: Colors.green[700])),
                      if (widget.product.mrp > widget.product.salesPrice)
                        Text('₹${widget.product.mrp.toInt()}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                  // Set explicit width for the button to prevent it from growing too large on Web
                  SizedBox(
                    width: widget.isWeb ? 90 : 75,
                    height: 35,
                    child: ProductAddButton(
                      product: widget.product,
                      isVariantRow: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}