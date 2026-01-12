import 'package:eshop/screen/home/product_screen.dart';
import 'package:eshop/screen/home/widgets/subcategory_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../model/home/category.dart';
import '../../model/home/subcategory.dart';
import '../../services/home/api_service.dart';
import '../../services/navigation_service.dart';
import '../../widget/main_header.dart';

class CategoriesScreen extends StatefulWidget {
  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> categories = [];
  List<Category> filteredCategories = [];
  bool isLoading = true;
  String searchQuery = '';
  int selectedCategoryIndex = -1;

  final Map<String, List<SubCategory>> _subcategoryCache = {};
  final Map<String, bool> _loadingStates = {};

  void debugCurrentCategories() {
    print('=== CURRENT CATEGORIES IN STATE ===');
    print('Categories length: ${categories.length}');
    print('FilteredCategories length: ${filteredCategories.length}');

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      print('State Category $i: ID="${category.id}", Name="${category.name}"');
    }
    print('=== END CURRENT CATEGORIES ===');
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    loadCategories().then((_) {
      debugCurrentCategories();
      _preloadVisibleSubcategories();
    });
  }

  void _preloadVisibleSubcategories() {
    if (filteredCategories.isNotEmpty) {
      final categoriesToPreload = filteredCategories.take(3).toList();
      for (final category in categoriesToPreload) {
        _loadSubcategories(category.id);
      }
    }
  }

  Future<void> loadCategories() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('=== STARTING TO LOAD CATEGORIES ===');
      final loadedCategories = await ApiService.getCategories();
      print('Received ${loadedCategories.length} categories from API');

      final validCategories = loadedCategories.where((category) {
        final isValid = category.id.isNotEmpty && category.name.isNotEmpty;
        if (!isValid) {
          print(
            'Filtering out invalid category: ID="${category.id}", Name="${category.name}"',
          );
        }
        return isValid;
      }).toList();

      print('=== FINAL VALID CATEGORIES ===');
      print('Total valid categories: ${validCategories.length}');
      print('=== END VALID CATEGORIES ===');

      setState(() {
        categories = validCategories;
        filteredCategories = validCategories;
        isLoading = false;
      });
    } catch (e) {
      print('ERROR in loadCategories: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<List<SubCategory>> _loadSubcategories(String categoryId) async {
    if (_subcategoryCache.containsKey(categoryId)) {
      return _subcategoryCache[categoryId]!;
    }

    if (_loadingStates[categoryId] == true) {
      while (_loadingStates[categoryId] == true) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      return _subcategoryCache[categoryId] ?? [];
    }

    _loadingStates[categoryId] = true;

    try {
      final subcategories = await ApiService.getSubCategories(categoryId);
      _subcategoryCache[categoryId] = subcategories;
      _loadingStates[categoryId] = false;

      _preloadImages(subcategories);

      return subcategories;
    } catch (e) {
      print('Error loading subcategories for category $categoryId: $e');
      _loadingStates[categoryId] = false;
      return [];
    }
  }

  void _preloadImages(List<SubCategory> subcategories) {
    for (final subcategory in subcategories.take(8)) {
      if (subcategory.image.isNotEmpty) {
        final imageUrl = ApiService.getImageUrl(subcategory.image, 'subcategory');
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).catchError((error) {
          print('Error preloading image: $error');
        });
      }
    }
  }

  void filterCategories(String query) {
    setState(() {
      searchQuery = query;
      filteredCategories = categories
          .where((category) =>
          category.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      if (query.isNotEmpty && filteredCategories.length <= 5) {
        for (final category in filteredCategories) {
          _loadSubcategories(category.id);
        }
      }
    });
  }

  Widget buildSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 12),
              _buildSkeletonGrid(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonGrid() {
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
    // --- FIX: Enable iOS Swipe ---
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return PopScope(
      // Allow pop on iOS to enable swipe gesture.
      canPop: isIOS,
      onPopInvoked: (didPop) {
        if (didPop) return;
        NavigationService.goBackToHomeScreen();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16), child: MainHeader()),
              Container(
                padding: EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: filterCategories,
                    decoration: InputDecoration(
                      hintText: 'What would you like to eat?',
                      prefixIcon: Icon(Icons.search, color: Colors.red),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
              ),

              if (!isLoading && categories.isNotEmpty)
                Container(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('All'),
                            selected: selectedCategoryIndex == -1,
                            onSelected: (selected) {
                              setState(() {
                                selectedCategoryIndex = -1;
                                filteredCategories = categories;
                              });
                            },
                            selectedColor: Colors.red,
                            labelStyle: TextStyle(
                              color: selectedCategoryIndex == -1
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        );
                      }

                      final categoryIndex = index - 1;
                      final category = categories[categoryIndex];

                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.name),
                          selected: selectedCategoryIndex == categoryIndex,
                          onSelected: (selected) {
                            setState(() {
                              selectedCategoryIndex = selected ? categoryIndex : -1;
                              filteredCategories = selected ? [category] : categories;
                            });

                            if (selected) {
                              _loadSubcategories(category.id);
                            }
                          },
                          selectedColor: Colors.red,
                          labelStyle: TextStyle(
                            color: selectedCategoryIndex == categoryIndex
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              Expanded(
                child: isLoading
                    ? buildSkeleton()
                    : LazyLoadListView(
                  categories: filteredCategories,
                  subcategoryCache: _subcategoryCache,
                  loadSubcategories: _loadSubcategories,
                  onSubcategoryTap: (subcategory, category) {
                    // Navigate directly to ProductsScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductsScreen(
                          categoryId: category.id,
                          subcategoryId: subcategory.id,
                          subcategoryName: subcategory.name,
                        ),
                      ),
                    );
                  },
                ),
              ),            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subcategoryCache.clear();
    _loadingStates.clear();
    super.dispose();
  }
}

class LazyLoadListView extends StatefulWidget {
  final List<Category> categories;
  final Map<String, List<SubCategory>> subcategoryCache;
  final Future<List<SubCategory>> Function(String) loadSubcategories;
  final Function(SubCategory, Category) onSubcategoryTap;

  const LazyLoadListView({
    Key? key,
    required this.categories,
    required this.subcategoryCache,
    required this.loadSubcategories,
    required this.onSubcategoryTap,
  }) : super(key: key);

  @override
  _LazyLoadListViewState createState() => _LazyLoadListViewState();
}

class _LazyLoadListViewState extends State<LazyLoadListView> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _visibleItems = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;

    const itemHeight = 200.0;
    final firstVisibleIndex = (scrollOffset / itemHeight).floor();
    final lastVisibleIndex = ((scrollOffset + viewportHeight) / itemHeight).ceil();

    for (int i = firstVisibleIndex; i <= lastVisibleIndex + 2 && i < widget.categories.length; i++) {
      if (i >= 0 && !_visibleItems.contains(i)) {
        _visibleItems.add(i);
        widget.loadSubcategories(widget.categories[i].id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.categories.length,
      itemBuilder: (context, index) {
        final category = widget.categories[index];
        return OptimizedCategorySection(
          category: category,
          subcategoryCache: widget.subcategoryCache,
          loadSubcategories: widget.loadSubcategories,
          onSubcategoryTap: (subcategory) => widget.onSubcategoryTap(subcategory, category),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class OptimizedCategorySection extends StatefulWidget {
  final Category category;
  final Map<String, List<SubCategory>> subcategoryCache;
  final Future<List<SubCategory>> Function(String) loadSubcategories;
  final Function(SubCategory) onSubcategoryTap;

  const OptimizedCategorySection({
    Key? key,
    required this.category,
    required this.subcategoryCache,
    required this.loadSubcategories,
    required this.onSubcategoryTap,
  }) : super(key: key);

  @override
  _OptimizedCategorySectionState createState() => _OptimizedCategorySectionState();
}

class _OptimizedCategorySectionState extends State<OptimizedCategorySection>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  Widget buildSubcategorySkeleton() {
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
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.category.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          widget.subcategoryCache.containsKey(widget.category.id)
              ? _buildSubcategoryGrid(widget.subcategoryCache[widget.category.id]!)
              : FutureBuilder<List<SubCategory>>(
            future: widget.loadSubcategories(widget.category.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return buildSubcategorySkeleton();
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

              return _buildSubcategoryGrid(snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryGrid(List<SubCategory> subcategories) {
    List<Widget> rows = [];

    for (int i = 0; i < subcategories.length; i += 4) {
      List<Widget> rowItems = [];

      for (int j = i; j < i + 4 && j < subcategories.length; j++) {
        final subcategory = subcategories[j];
        rowItems.add(
          Expanded(
            child: SubcategoryItem(
              subcategory: subcategory,
              onTap: () => widget.onSubcategoryTap(subcategory),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: rowItems,
        ),
      );

      // Add spacing between rows
      if (i + 4 < subcategories.length) {
        rows.add(SizedBox(height: 16));
      }
    }

    return Column(
      children: rows,
    );
  }
}