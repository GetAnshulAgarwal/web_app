import 'dart:async';
import 'package:eshop/screen/home/search/search_page.dart';
import 'package:flutter/material.dart' hide Banner, CarouselController;
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../model/home/category.dart';
import '../model/home/product_model.dart';
import '../model/home/subcategory.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/home/api_service.dart';
import '../services/home/banner_api_service.dart';
import '../services/warehouse/testing_warehouse_service.dart';
import '../services/warehouse/warehouse_mode_controller.dart';
import '../widget/home/USPBanner.dart';
import '../widget/home/banner_carousel.dart';
import '../widget/home/optimized_network.dart';
import '../widget/main_header.dart';
import '../widget/skeleton_widgets.dart';
import 'address_screen.dart';
import 'home/banner_products_screen.dart';
import 'home/product_screen.dart';
import '../model/home/banner_model.dart' as banner_model;
import 'home/widgets/category_products_section.dart';
import 'home/widgets/subcategory_grid.dart';
import 'home/widgets/subcategory_section.dart';
import '../authentication/user_data.dart';

// Optimized List Item Classes
abstract class HomeListItem {}

class ProductSectionItem extends HomeListItem {
  final Category category;
  ProductSectionItem(this.category);
}

class BannerItem extends HomeListItem {
  final String folderName;
  BannerItem(this.folderName);
}

class SubCategorySectionItem extends HomeListItem {
  final Category category;
  SubCategorySectionItem(this.category);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  bool _isCheckingServiceability = false;
  bool _isLocationServiceable = false;
  List<Category> categories = [];
  List<HomeListItem> _optimizedSubCategoryList = [];
  List<HomeListItem> _optimizedProductList = [];
  bool isLoading = true;
  bool _isInitialized = false;
  bool _routeSubscribed = false;
  bool _isNavigating = false;
  StreamSubscription<Map<String, dynamic>>? _serviceabilitySubscription;
  int selectedCategoryIndex = -1;
  String currentGreeting = 'Good Morning';
  Timer? _greetingTimer;
  bool _disposed = false;

  final List<String> _inlineBannerFolders = ['F2', 'F3', 'F4', '25', '3', '5', '6', '7'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateGreeting();
    _setupGreetingTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      _setupServiceabilityListener();
      context.read<LocationProvider>().startLocationTracking();
      if (mounted) setState(() => isLoading = true);
      final results = await Future.wait([ApiService.getCategories()]);
      if (_disposed || !mounted) return;
      final loadedCategories = results[0] as List<Category>;
      _prepareOptimizedLists(loadedCategories);
      setState(() {
        categories = loadedCategories;
        isLoading = false;
      });
      Future.microtask(() {
        _checkWarehouseServiceability();
        _preloadCriticalImages();
        Provider.of<LocationProvider>(context, listen: false)
            .fetchCurrentLocationAndCheckZone(forceUpdate: false);
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _prepareOptimizedLists(List<Category> sourceCategories) {
    _optimizedSubCategoryList.clear();
    _optimizedProductList.clear();
    if (sourceCategories.isEmpty) return;
    final displayList = selectedCategoryIndex == -1 ? sourceCategories : [sourceCategories[selectedCategoryIndex]];

    int bannerIndexSub = 0;
    for (int i = 0; i < displayList.length; i++) {
      _optimizedSubCategoryList.add(SubCategorySectionItem(displayList[i]));
      if (_inlineBannerFolders.isNotEmpty && (i + 1) % 2 == 0 && i < displayList.length - 1) {
        _optimizedSubCategoryList.add(BannerItem(_inlineBannerFolders[bannerIndexSub]));
        bannerIndexSub = (bannerIndexSub + 1) % _inlineBannerFolders.length;
      }
    }

    int bannerIndexProd = 0;
    if (sourceCategories.length > 1) bannerIndexProd = (sourceCategories.length - 1) ~/ 2 % _inlineBannerFolders.length;
    for (int i = 0; i < displayList.length; i++) {
      _optimizedProductList.add(ProductSectionItem(displayList[i]));
      if (_inlineBannerFolders.isNotEmpty && (i + 1) % 3 == 0 && i < displayList.length - 1) {
        _optimizedProductList.add(BannerItem(_inlineBannerFolders[bannerIndexProd]));
        bannerIndexProd = (bannerIndexProd + 1) % _inlineBannerFolders.length;
      }
    }
  }

  void _preloadCriticalImages() {
    if (_disposed || !mounted) return;
    try {
      final imagesToLoad = categories.take(4).where((c) => c.image.isNotEmpty).map((c) => ApiService.getImageUrl(c.image, 'category'));
      for (final url in imagesToLoad) {
        if (mounted) precacheImage(CachedNetworkImageProvider(url), context);
      }
    } catch (e) {}
  }

  void _setupServiceabilityListener() {
    _serviceabilitySubscription = context.read<LocationProvider>().onServiceabilityChange.listen((event) {
      if (!mounted || _disposed) return;
      setState(() => _isLocationServiceable = event['isServiceable'] as bool);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _serviceabilitySubscription?.cancel();
    _greetingTimer?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkWarehouseServiceability() async {
    if (_isCheckingServiceability) return;
    _isCheckingServiceability = true;
    try {
      if (WarehouseModeController.isTestingMode) {
        final isValid = await TestingWarehouseService.validateTestingServiceability();
        if (mounted) setState(() => _isLocationServiceable = isValid);
      } else {
        await Provider.of<LocationProvider>(context, listen: false).fetchCurrentLocationAndCheckZone(forceUpdate: false);
      }
    } finally {
      if (mounted) _isCheckingServiceability = false;
    }
  }

  Future<void> _handleRefresh() async {
    if (_disposed) return;
    try {
      ApiService.clearCache();
      final loadedCategories = await ApiService.getCategories();
      if (mounted) {
        _prepareOptimizedLists(loadedCategories);
        setState(() => categories = loadedCategories);
        _checkWarehouseServiceability();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to refresh data');
    }
  }

  // --- WEB OPTIMIZED WRAPPER ---
  Widget _webResponsiveWrapper({required List<Widget> slivers}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // Standard website content width
        child: CustomScrollView(
          key: const PageStorageKey<String>('home_scroll'),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: slivers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isNavigating || _disposed) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Colors.red,
          child: isLoading && categories.isEmpty
              ? _buildLoadingContent()
              : _webResponsiveWrapper(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: _isCheckingServiceability
                    ? _buildDeliveryStatusSkeleton()
                    : const USPBannerWidget(),
              ),
              ..._buildSliverMainContent(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSliverMainContent() {
    final bool isSpecificCategorySelected = selectedCategoryIndex != -1;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth > 800;

    return [
      if (!isLoading && categories.isNotEmpty) ...[
        SliverToBoxAdapter(child: _buildCategoryChips()),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],

      // Hero Banner - Full width on Web
      if (!isLoading && !isSpecificCategorySelected) ...[
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: isWeb ? 0 : 16, vertical: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
              child: BannerCarousel(
                onBannerTap: _handleBannerTap,
                aspectRatio: isWeb ? 3.5 / 1 : 1.8 / 1, // Wider banner for Web
                folderName: 'F1',
              ),
            ),
          ),
        ),
      ],

      // Shop by Category Grid
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          child: _buildCategoriesSection(isWeb),
        ),
      ),

      if (!isLoading && categories.isNotEmpty && !isSpecificCategorySelected)
        SliverToBoxAdapter(child: _buildPopularSubcategoriesSection()),

      if (isLoading)
        SliverToBoxAdapter(child: _buildInitialLoadingSkeleton())
      else ...[
        _buildLazySubcategoryList(),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        _buildLazyProductList(),
      ],

      const SliverToBoxAdapter(child: SizedBox(height: 80)),
    ];
  }

  Widget _buildHeader() {
    final bool isWeb = MediaQuery.of(context).size.width > 800;
    return Container(
      padding: EdgeInsets.symmetric(vertical: isWeb ? 24 : 0),
      color: Colors.white,
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: MainHeader()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$currentGreeting,', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const Text('What would you like to order?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (!isWeb)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.wb_sunny, color: Colors.orange),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchBar(isWeb),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isWeb) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWeb ? 800 : double.infinity),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(30), // Pill shape for web
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.red),
                const SizedBox(width: 12),
                Text('Search for groceries, veggies and more...', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildCategoriesSection(bool isWeb) {
    if (categories.isEmpty) return Container();
    final int crossAxisCount = isWeb ? 6 : 3; // Show 6 items per row on Web
    final displayCategories = isWeb ? categories.take(12).toList() : categories.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shop by Category', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: _showAllCategoriesBottomSheet,
                child: const Text('View All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: displayCategories.length,
            itemBuilder: (context, index) => _buildSimpleCategoryCard(displayCategories[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleCategoryCard(Category category) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateToSubcategories(category),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: category.image.isNotEmpty ? OptimizedNetworkImage(imageUrl: category.image, imageType: 'category') : const SizedBox(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                child: Text(
                  category.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Optimized Render Methods
  Widget _buildLazySubcategoryList() {
    if (_optimizedSubCategoryList.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = _optimizedSubCategoryList[index];
        if (item is SubCategorySectionItem) {
          return SubcategorySection(
            key: ValueKey('main_sub_${item.category.id}'),
            category: item.category,
            onSubcategoryTap: (subcategory) => _navigateToSubcategories(item.category, selectedSubcategoryId: subcategory.id),
            maxItemsToShow: 8,
            showTitle: true,
            padding: const EdgeInsets.symmetric(vertical: 24),
          );
        } else if (item is BannerItem) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BannerCarousel(onBannerTap: _handleBannerTap, aspectRatio: 3.0 / 1, folderName: item.folderName),
            ),
          );
        }
        return const SizedBox.shrink();
      }, childCount: _optimizedSubCategoryList.length),
    );
  }

  Widget _buildLazyProductList() {
    if (_optimizedProductList.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = _optimizedProductList[index];
        if (item is ProductSectionItem) {
          return CategoryProductsSection(key: ValueKey('prod_${item.category.id}'), category: item.category);
        } else if (item is BannerItem) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BannerCarousel(onBannerTap: _handleBannerTap, aspectRatio: 4 / 1, folderName: item.folderName),
            ),
          );
        }
        return const SizedBox.shrink();
      }, childCount: _optimizedProductList.length, addAutomaticKeepAlives: true),
    );
  }

  // Standard logic and UI helpers remain the same...
  void _updateGreeting() {
    if (_disposed) return;
    final hour = DateTime.now().hour;
    String greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : hour < 21 ? 'Good Evening' : 'Good Night';
    if (greeting != currentGreeting && mounted) setState(() => currentGreeting = greeting);
  }

  void _setupGreetingTimer() {
    _greetingTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _updateGreeting();
    });
  }

  void _navigateToSubcategories(Category category, {String? selectedSubcategoryId}) async {
    _isNavigating = true;
    final subcategories = await ApiService.getSubCategories(category.id);
    if (!mounted) return;
    final target = selectedSubcategoryId != null ? subcategories.firstWhere((s) => s.id == selectedSubcategoryId, orElse: () => subcategories.first) : subcategories.first;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(categoryId: category.id, subcategoryId: target.id, subcategoryName: target.name)));
    _isNavigating = false;
  }

  void _handleBannerTap(banner_model.Banner banner, int mediaIndex) async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.red)));
    try {
      banner_model.BannerMedia? specificMedia;
      if (banner.media != null && mediaIndex < banner.media!.length) specificMedia = banner.media![mediaIndex];
      final products = specificMedia != null ? await BannerApiService.getProductsForSpecificMedia(banner, specificMedia) : await BannerApiService.getProductsForBanner(banner);
      if (!mounted) return;
      Navigator.pop(context);
      if (products.isEmpty) { _showErrorSnackBar('No products available'); return; }
      Navigator.push(context, MaterialPageRoute(builder: (context) => BannerProductsScreen(banner: banner, products: products, mediaItem: specificMedia)));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Failed to load products');
    }
  }

  void _showErrorSnackBar(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  }

  Widget _buildLoadingContent() {
    return Column(children: [const Padding(padding: EdgeInsets.all(16), child: MainHeader()), SkeletonWidgets.buildInitialLoadingSkeleton(message: 'Loading...', dotColor: Colors.red)]);
  }

  Widget _buildDeliveryStatusSkeleton() => Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: SkeletonWidgets.buildCardSkeleton(width: double.infinity, height: 60));
  Widget _buildInitialLoadingSkeleton() => SkeletonWidgets.buildInitialLoadingSkeleton(message: 'Loading categories...', dotColor: Colors.red);
  Widget _buildHorizontalSubcategorySkeleton() => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: List.generate(4, (i) => Expanded(child: SkeletonWidgets.buildCardSkeleton(width: 80, height: 80)))));

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final label = isAll ? 'All' : categories[index - 1].name;
          final isSelected = isAll ? selectedCategoryIndex == -1 : selectedCategoryIndex == index - 1;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) { setState(() { selectedCategoryIndex = isAll ? -1 : index - 1; _prepareOptimizedLists(categories); }); },
              selectedColor: Colors.red,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
              backgroundColor: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  void _showAllCategoriesBottomSheet() {
    if (!mounted) return;
    final sortedCategories = List<Category>.from(categories)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(20), child: Text('All Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: sortedCategories.length,
                itemBuilder: (context, index) => _buildSimpleCategoryCard(sortedCategories[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSubcategoriesSection() {
    if (categories.isEmpty) return const SizedBox.shrink();
    final randomCategory = categories.first;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Trending in Your Area', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: FutureBuilder<List<SubCategory>>(
              future: ApiService.getSubCategories(randomCategory.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildHorizontalSubcategorySkeleton();
                return SubcategoryGrid(subcategories: snapshot.data!, onSubcategoryTap: (s) => _navigateToSubcategories(randomCategory, selectedSubcategoryId: s.id), maxItemsToShow: 6, imageSize: 90, padding: const EdgeInsets.symmetric(horizontal: 16));
              },
            ),
          ),
        ],
      ),
    );
  }
}