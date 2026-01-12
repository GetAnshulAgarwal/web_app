// Add this after your HomeScreen class
/*import 'package:flutter/material.dart';

import '../../model/home/product_model.dart';
import '../../screen/home/product_detail_screen.dart';
import '../../services/stock_service.dart';

class SearchResultAddButton extends StatefulWidget {
  final Product product;

  const SearchResultAddButton({Key? key, required this.product}) : super(key: key);

  @override
  State<SearchResultAddButton> createState() => _SearchResultAddButtonState();
}

class _SearchResultAddButtonState extends State<SearchResultAddButton> {
  int currentStock = 0;
  bool isLoadingStock = true;
  bool hasStockError = false;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    try {
      setState(() {
        isLoadingStock = true;
        hasStockError = false;
      });

      final stockResponse = await StockService.getItemStock(widget.product.id);

      if (mounted) {
        setState(() {
          currentStock = stockResponse?.currentStock ?? 0;
          isLoadingStock = false;
          hasStockError = stockResponse == null;
        });
      }
    } catch (e) {
      print('❌ Error loading stock for ${widget.product.itemName}: $e');
      if (mounted) {
        setState(() {
          currentStock = 0;
          isLoadingStock = false;
          hasStockError = true;
        });
      }
    }
  }

  void _showStockMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingStock) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
          ),
        ),
      );
    }

    if (hasStockError) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Center(
          child: Text(
            'N/A',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (currentStock == 0) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Center(
          child: Text(
            'UNAVAILABLE',
            style: TextStyle(
              fontSize: 8,
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: () {
        // Navigate to product detail screen instead of direct add
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: widget.product,
              categoryId: null, // From search
              subcategoryId: null,
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.green,
        side: BorderSide(color: Colors.green, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: EdgeInsets.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'VIEW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (currentStock <= 5)
            Text(
              '$currentStock left',
              style: TextStyle(
                fontSize: 7,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}*/