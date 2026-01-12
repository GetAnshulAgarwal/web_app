import 'dart:math' as math;
import 'package:eshop/Animation/bouncing_dots.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../model/home/trending_in_city_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../services/home/api_service.dart';
import '../../../services/search_service.dart';
import '../../../providers/recent_searches_provider.dart';
import '../../../model/home/product_model.dart';
import 'dart:async';

import '../../../services/stock_service.dart';
import '../../../widget/product_add_button.dart';
import '../product_detail_screen.dart';
import '../product_screen.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  int _requestId = 0;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchFocusNode = FocusNode();

  List<Product> _productResults = [];
  List<String> _suggestions = [];
  List<Product> _cachedSuggestionProducts = [];
  late final List<String> _popularSearches;

  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  String _searchQuery = '';
  String _lastFetchedQuery = '';
  Timer? _debounceTimer;

  List<Product>? _cachedPopularProducts;
  List<Data>? _trendingTilesData;
  bool _isLoadingTrendingTiles = true;

  @override
  void initState() {
    super.initState();
    _popularSearches = SearchService.getPopularSearches();

    Future.microtask(() {
      for (final search in _popularSearches.take(3)) {
        SearchService.searchProducts(search);
      }
    });

    Future.microtask(() => _loadTrendingTiles());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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

    return [...singles, ...representativeProducts];
  }

  Future<void> _loadTrendingTiles() async {
    try {
      // INCREASED TIMEOUT to 20 seconds to handle larger data sets
      final response = await ApiService.getTrendingTiles().timeout(
        const Duration(seconds: 20),
      );

      if (response['success'] == true && response['data'] != null) {
        final trendingData = TrendingInCity.fromJson(response);
        if (mounted) {
          setState(() {
            _trendingTilesData = trendingData.data;
            _isLoadingTrendingTiles = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingTrendingTiles = false);
      }
    } catch (e) {
      // ADD LOGGING to see the actual error (Timeout vs Parsing)
      debugPrint("Error loading trending tiles: $e");
      if (mounted) setState(() => _isLoadingTrendingTiles = false);
    }
  }

  Future<void> _performSearch(
    String query, {
    bool suggestionsOnly = false,
  }) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _productResults = [];
        _cachedSuggestionProducts = [];
        _lastFetchedQuery = '';
        _isSearching = false;
        _isLoadingSuggestions = false;
      });
      return;
    }

    final currentRequestId = ++_requestId;

    try {
      if (suggestionsOnly) {
        setState(() => _isLoadingSuggestions = true);

        if (_cachedSuggestionProducts.isNotEmpty &&
            _lastFetchedQuery.toLowerCase() == query.toLowerCase()) {
          final productSuggestions =
              _cachedSuggestionProducts
                  .map((p) => p.itemName)
                  .toSet()
                  .take(5)
                  .toList();
          final recentProvider = context.read<RecentSearchesProvider>();
          final localSuggestions = SearchService.generateSuggestions(
            query,
            recentProvider.recentSearches,
          );

          final combined =
              {
                ...localSuggestions.take(3),
                ...productSuggestions.take(5),
              }.take(8).toList();

          if (mounted && currentRequestId == _requestId) {
            setState(() {
              _suggestions = combined;
              _isLoadingSuggestions = false;
            });
          }
          return;
        }

        final results = await SearchService.searchProducts(query);
        if (!mounted || currentRequestId != _requestId) return;

        _cachedSuggestionProducts = results;
        _lastFetchedQuery = query;

        final productSuggestions =
            results.map((p) => p.itemName).toSet().take(5).toList();
        final recentProvider = context.read<RecentSearchesProvider>();
        final localSuggestions = SearchService.generateSuggestions(
          query,
          recentProvider.recentSearches,
        );
        final combined =
            {
              ...localSuggestions.take(3),
              ...productSuggestions.take(5),
            }.take(8).toList();

        setState(() {
          _suggestions = combined;
          _isLoadingSuggestions = false;
        });
      } else {
        setState(() {
          _isSearching = true;
          _suggestions = [];
        });

        if (_cachedSuggestionProducts.isNotEmpty &&
            _lastFetchedQuery.toLowerCase() == query.toLowerCase()) {
          if (mounted && currentRequestId == _requestId) {
            setState(() {
              _productResults = _groupProducts(_cachedSuggestionProducts);
              _isSearching = false;
            });
          }
          return;
        }

        final results = await SearchService.searchProducts(query);
        if (!mounted || currentRequestId != _requestId) return;

        setState(() {
          _productResults = _groupProducts(results);
          _cachedSuggestionProducts = results;
          _lastFetchedQuery = query;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted && currentRequestId == _requestId) {
        setState(() {
          _suggestions = [];
          _productResults = [];
          _isSearching = false;
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _productResults = [];
        _isSearching = false;
        _isLoadingSuggestions = false;
      });
      return;
    }
    _debounceTimer = Timer(_debounceDuration, () {
      if (_searchQuery == query && mounted) {
        _performSearch(query, suggestionsOnly: true);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    _debounceTimer?.cancel();
    context.read<RecentSearchesProvider>().addSearch(query);
    setState(() {
      _searchQuery = query;
      _suggestions = [];
      _isLoadingSuggestions = false;
    });
    _searchFocusNode.unfocus();
    _performSearch(query, suggestionsOnly: false);
  }

  void _handleSearchSelection(String term) {
    _debounceTimer?.cancel();
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    context.read<RecentSearchesProvider>().addSearch(term);
    setState(() {
      _searchQuery = term;
      _suggestions = [];
      _isLoadingSuggestions = false;
    });
    _searchFocusNode.unfocus();
    _performSearch(term, suggestionsOnly: false);
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _suggestions = [];
      _productResults = [];
      _isSearching = false;
    });
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Consumer<RecentSearchesProvider>(
        builder:
            (context, recentProvider, _) => Column(
              children: [
                if (recentProvider.recentSearches.isNotEmpty &&
                    _searchQuery.isEmpty &&
                    !_isLoadingSuggestions)
                  _buildRecentSearches(recentProvider),
                Expanded(child: _buildMainContent()),
              ],
            ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search products...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: _clearSearch,
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _onSearchSubmitted,
        ),
      ),
    );
  }

  Widget _buildRecentSearches(RecentSearchesProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              GestureDetector(
                onTap: () => provider.clearSearches(),
                child: Text('Clear', style: TextStyle(color: Colors.red[600])),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                provider.recentSearches
                    .map((s) => _buildChip(s, () => _handleSearchSelection(s)))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, VoidCallback onTap) {
    return ActionChip(
      label: Text(text),
      onPressed: onTap,
      backgroundColor: Colors.grey[100],
      shape: StadiumBorder(side: BorderSide.none),
    );
  }

  Widget _buildMainContent() {
    if (_searchQuery.isNotEmpty &&
        (_isLoadingSuggestions || _suggestions.isNotEmpty))
      return _buildSuggestionsSection();
    if (_isSearching) return const Center(child: BouncingDotsIndicator());
    if (_productResults.isNotEmpty) return _buildSearchResults();
    if (_searchQuery.isNotEmpty && !_isSearching)
      return _buildEmptyState(
        Icons.search_off,
        'No results',
        'Try something else',
      );
    return _buildPopularSearches();
  }

  Widget _buildSuggestionsSection() {
    return ListView(
      children: [
        if (_isLoadingSuggestions) const LinearProgressIndicator(),
        ..._suggestions.map(
          (s) => ListTile(
            leading: Icon(Icons.search),
            title: Text(s),
            onTap: () => _handleSearchSelection(s),
          ),
        ),
        if (_cachedSuggestionProducts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Text(
              'Products',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _buildProductGrid(_groupProducts(_cachedSuggestionProducts)),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView(
      controller: _scrollController,
      children: [const SizedBox(height: 8), _buildProductGrid(_productResults)],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPopularSearches() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending in your city',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTrendingGrid(),
          const SizedBox(height: 24),
          const Text(
            'Popular Products',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Product>>(
            future: _getPopularProducts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return _buildProductGrid(snapshot.data!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCardFromApi(Data tileData, int index) {
    final label = tileData.label ?? 'Item';

    // FIX 1: Safely extract images preventing "Bad state: No element" error
    final images = tileData.items
        ?.take(2)
        .map((item) {
      // Check if list exists AND is not empty
      if (item.itemImages != null && item.itemImages!.isNotEmpty) {
        return item.itemImages!.first;
      }
      return null;
    })
        .whereType<String>()
        .toList() ??
        [];

    return InkWell(
      onTap: () {
        if (tileData.items != null && tileData.items!.isNotEmpty) {
          final products = tileData.items!.map((item) => Product(
            id: item.sId ?? '',
            itemName: item.itemName ?? '',
            brand: item.brand ?? '',
            salesPrice: (item.salesPrice ?? 0).toDouble(),
            mrp: (item.mrp ?? 0).toDouble(),
            itemImages: item.itemImages ?? [],
            unit: '',
            description: '',
            stock: item.currentStock ?? 0,
            itemGroup: null,
            parentItemId: null,
            variantName: null,
          )).toList();

          setState(() {
            _productResults = _groupProducts(products);
            _searchQuery = label;
            _searchController.text = label;
          });
          _searchFocusNode.unfocus();
        } else {
          _handleSearchSelection(label);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.primaries[index % Colors.primaries.length]
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text Label
              Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis
              ),

              const Spacer(),

              // FIX 2: Reduced height to 50 to solve the 7px-16px overflow
              SizedBox(
                height: 50,
                child: Row(
                    children: images
                        .map((img) => Expanded(
                        child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ApiService.getImageUrl(img, 'item'),
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                              ),
                            ))))
                        .toList()),
              ),
            ]
        ),
      ),
    );
  }
  Widget _buildTrendingGrid() {
    if (_isLoadingTrendingTiles)
      return const Center(child: CircularProgressIndicator());
    if (_trendingTilesData == null) return const SizedBox();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _trendingTilesData!.length,
      itemBuilder:
          (context, index) =>
              _buildTrendingCardFromApi(_trendingTilesData![index], index),
    );
  }

  Future<List<Product>> _getPopularProducts() async {
    if (_cachedPopularProducts != null) return _cachedPopularProducts!;
    try {
      final results = await SearchService.searchProducts('popular');
      _cachedPopularProducts = _groupProducts(results).take(6).toList();
      return _cachedPopularProducts!;
    } catch (e) {
      return [];
    }
  }

  Widget _buildProductGrid(List<Product> products) {
    // CHANGE: Changed from 3 columns to 2 columns to fix overflow error
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // Update logic for 2 items per row
      itemCount: (products.length / 2).ceil(),
      itemBuilder: (context, index) {
        final firstIndex = index * 2;
        final secondIndex = firstIndex + 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CompactProductCard(product: products[firstIndex]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    secondIndex < products.length
                        ? CompactProductCard(product: products[secondIndex])
                        : const SizedBox(), // Empty spacer if odd number of items
              ),
            ],
          ),
        );
      },
    );
  }
}

class CompactProductCard extends StatefulWidget {
  final Product product;
  const CompactProductCard({super.key, required this.product});

  @override
  State<CompactProductCard> createState() => _CompactProductCardState();
}

class _CompactProductCardState extends State<CompactProductCard> {
  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: widget.product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child:
                    widget.product.itemImages.isNotEmpty
                        ? Image.network(
                          ApiService.getImageUrl(
                            widget.product.itemImages.first,
                            'item',
                          ),
                          fit: BoxFit.contain,
                        )
                        : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${widget.product.salesPrice.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // ✅ INCREASED HEIGHT to fit the larger button
                  SizedBox(
                    height: 38.0,
                    child: ProductAddButton(product: widget.product),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
