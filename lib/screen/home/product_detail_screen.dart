import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/home/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/home/api_service.dart';
import '../../services/stock_service.dart';
import '../../widget/product_add_button.dart';
import '../cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String? categoryId;
  final String? subcategoryId;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.categoryId,
    this.subcategoryId,
  });

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentStock = 0;
  bool _isLoadingStock = true;
  bool _hasStockError = false;
  int _currentImageIndex = 0;
  bool _isProcessing = false;
  int _optimisticQuantity = 0;
  late AnimationController _animationController;
  List<Product> _relatedProducts = [];
  bool _loadingRelatedProducts = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        _optimisticQuantity = cartProvider.getItemQuantity(widget.product.id);
        _loadRelatedProducts();
        _loadStock();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    try {
      setState(() {
        _isLoadingStock = true;
        _hasStockError = false;
      });
      final stockResponse = await StockService.getItemStock(widget.product.id);
      if (mounted) {
        setState(() {
          _currentStock = stockResponse?.currentStock ?? 0;
          _isLoadingStock = false;
          _hasStockError = stockResponse == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStock = 0;
          _isLoadingStock = false;
          _hasStockError = true;
        });
      }
    }
  }

  Future<void> _loadRelatedProducts() async {
    setState(() => _loadingRelatedProducts = true);
    try {
      List<Product> products = [];
      if (widget.categoryId != null) {
        products = await ApiService.getProductsForCategory(widget.categoryId!, limit: 20);
      } else {
        final categories = await ApiService.getCategories();
        for (final category in categories.take(3)) {
          final catProducts = await ApiService.getProductsForCategory(category.id, limit: 7);
          products.addAll(catProducts);
          if (products.length >= 15) break;
        }
      }
      setState(() {
        _relatedProducts = products.where((p) => p.id != widget.product.id).take(10).toList();
        _loadingRelatedProducts = false;
      });
    } catch (e) {
      setState(() => _loadingRelatedProducts = false);
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor, SnackBarAction? action}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          action: action,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  Future<void> _updateCartQuantity(int newQuantity) async {
    if (_isProcessing) return;
    if (newQuantity > _currentStock) {
      _showSnackBar('Item reached stock limit!', backgroundColor: Colors.orange);
      return;
    }
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final currentQuantity = cartProvider.getItemQuantity(widget.product.id);
    setState(() {
      _optimisticQuantity = newQuantity;
      _isProcessing = true;
    });
    try {
      if (newQuantity > 0) {
        if (currentQuantity == 0) {
          await cartProvider.addItemToCart(itemId: widget.product.id, quantity: newQuantity);
        } else {
          await cartProvider.updateItemQuantity(itemId: widget.product.id, newQuantity: newQuantity);
        }
      } else {
        await cartProvider.removeItemFromCart(itemId: widget.product.id);
      }
      if (mounted && currentQuantity == 0 && newQuantity > 0) {
        _showSnackBar('Item added to cart!', backgroundColor: Colors.green);
      }
    } catch (e) {
      _showSnackBar('Action failed', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  double _safeToDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isWeb ? _buildWebAppBar() : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: isWeb ? _buildWebLayout() : _buildMobileLayout(),
        ),
      ),
      bottomNavigationBar: isWeb ? null : _buildBottomBar(false),
    );
  }

  PreferredSizeWidget _buildWebAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: const Text('Product Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Consumer<CartProvider>(
          builder: (context, cart, _) => TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.green),
            label: Text('${cart.totalItemsInCart} Items', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _buildImageCarousel(true),
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductInfo(),
                const SizedBox(height: 30),
                _buildPriceSection(),
                const SizedBox(height: 30),
                _buildBottomBar(true),
                const SizedBox(height: 40),
                const Divider(),
                _buildProductFeatures(),
                const SizedBox(height: 40),
                _buildRelatedProducts(isGrid: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(background: _buildImageCarousel(false)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    _buildProductInfo(),
                    const SizedBox(height: 20),
                    _buildPriceSection(),
                    const SizedBox(height: 20),
                    _buildProductFeatures(),
                    const SizedBox(height: 20),
                    _buildRelatedProducts(isGrid: false),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageCarousel(bool isWeb) {
    final images = widget.product.itemImages.isNotEmpty ? widget.product.itemImages : ['placeholder'];
    return Column(
      children: [
        AspectRatio(
          aspectRatio: isWeb ? 1 : 1.2,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemCount: images.length,
            itemBuilder: (context, index) => Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[50],
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: images[index] == 'placeholder'
                  ? Center(child: Opacity(opacity: 0.3, child: Image.asset('assets/images/app_logo.png', width: 100)))
                  : Image.network(ApiService.getImageUrl(images[index], 'item'), fit: BoxFit.contain),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: images.asMap().entries.map((e) => Container(
              width: _currentImageIndex == e.key ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentImageIndex == e.key ? Colors.green : Colors.grey[300],
              ),
            )).toList(),
          ),
        ]
      ],
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.product.brand.isNotEmpty)
            Chip(label: Text(widget.product.brand.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.green)), backgroundColor: Colors.green[50]),
          Text(widget.product.displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 10),
          Row(children: const [Icon(Icons.star, size: 18, color: Colors.amber), SizedBox(width: 5), Text('4.2 (120 reviews)', style: TextStyle(color: Colors.grey))]),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    final sales = _safeToDouble(widget.product.salesPrice);
    final mrp = _safeToDouble(widget.product.mrp);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('₹${sales.toInt()}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              if (mrp > sales) ...[
                const SizedBox(width: 15),
                Text('₹${mrp.toInt()}', style: const TextStyle(fontSize: 20, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 10),
                Text('${((mrp - sales) / mrp * 100).toInt()}% OFF', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Why shop with us?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 15),
        _buildFeatureItem(Icons.timer, '12 Min Delivery', 'Lightning fast doorstep service'),
        _buildFeatureItem(Icons.verified_user, 'Quality Guarantee', 'Only the freshest products'),
        _buildFeatureItem(Icons.assignment_return, 'Easy Returns', 'No questions asked policy'),      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.green[50], child: Icon(icon, color: Colors.green, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildRelatedProducts({required bool isGrid}) {
    if (_loadingRelatedProducts) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.all(20), child: Text('Similar Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        isGrid
            ? GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 0.7),
          itemCount: _relatedProducts.length,
          itemBuilder: (context, i) => _buildRelatedProductCard(_relatedProducts[i]),
        )
            : SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _relatedProducts.length,
            itemBuilder: (context, i) => _buildRelatedProductCard(_relatedProducts[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedProductCard(Product product) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Expanded(child: Image.network(ApiService.getImageUrl(product.itemImages.first, 'item'), fit: BoxFit.contain)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(product.itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ProductAddButton(product: product),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isWeb) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final qty = cart.getItemQuantity(widget.product.id);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: isWeb ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              if (qty > 0) ...[
                _buildQtySelector(qty),
                const SizedBox(width: 20),
              ],
              Expanded(child: _buildMainActionButton(qty, cart)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQtySelector(int qty) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          IconButton(onPressed: () => _updateCartQuantity(qty - 1), icon: const Icon(Icons.remove, color: Colors.green)),
          Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: () => _updateCartQuantity(qty + 1), icon: const Icon(Icons.add, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(int qty, CartProvider cart) {
    if (_currentStock == 0 && !_isLoadingStock) {
      return ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 50)),
        child: const Text('NOTIFY ME', style: TextStyle(color: Colors.white)),
      );
    }
    return ElevatedButton(
      onPressed: qty > 0 ? () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CartScreen())) : () => _updateCartQuantity(1),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
      child: Text(qty > 0 ? 'VIEW CART (${cart.totalItemsInCart})' : 'ADD TO CART', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}