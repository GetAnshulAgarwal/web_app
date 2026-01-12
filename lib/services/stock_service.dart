// services/stock_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../authentication/user_data.dart';

class StockService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/stock';

  /// Get stock for a specific item from user's assigned warehouse
  static Future<StockResponse?> getItemStock(String itemId) async {
    try {
      // Get user's assigned warehouse
      final userData = UserData();
      final user = userData.getCurrentUser();

      if (user == null || user.selectedWarehouseId == null) {
        print('❌ No warehouse assigned to user');
        return null;
      }

      return await getItemStockFromWarehouse(itemId, user.selectedWarehouseId!);
    } catch (e) {
      print('❌ Error fetching stock: $e');
      return null;
    }
  }

  /// Get stock for a specific item from a specific warehouse - ADD THIS METHOD
  static Future<StockResponse?> getItemStockFromWarehouse(
      String itemId,
      String warehouseId
      ) async {
    try {
      final url = Uri.parse('$baseUrl/$itemId?warehouse=$warehouseId');

      print('🔍 Fetching stock for item: $itemId from warehouse: $warehouseId');

      final userData = UserData();
      final user = userData.getCurrentUser();

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (user?.token != null) 'Authorization': 'Bearer ${user!.token}',
        },
      );

      print('📡 Stock API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return StockResponse.fromJson(jsonData);
      } else {
        print('❌ Failed to fetch stock: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching stock from warehouse: $e');
      return null;
    }
  }

  /// Get stock status with user-friendly message - ADD THIS METHOD
  static Future<StockStatus> getStockStatus(String itemId) async {
    final stock = await getItemStock(itemId);

    if (stock == null) {
      return StockStatus(
        isAvailable: false,
        currentStock: 0,
        message: 'Stock information unavailable',
        statusType: StockStatusType.unavailable,
      );
    }

    return _determineStockStatus(stock.currentStock);
  }

  static StockStatus _determineStockStatus(int stock) {
    if (stock == 0) {
      return StockStatus(
        isAvailable: false,
        currentStock: stock,
        message: 'Out of stock',
        statusType: StockStatusType.outOfStock,
      );
    } else if (stock <= 2) {
      return StockStatus(
        isAvailable: true,
        currentStock: stock,
        message: 'Only $stock left - Order soon!',
        statusType: StockStatusType.lowStock,
      );
    } else if (stock <= 10) {
      return StockStatus(
        isAvailable: true,
        currentStock: stock,
        message: '$stock available',
        statusType: StockStatusType.limitedStock,
      );
    } else {
      return StockStatus(
        isAvailable: true,
        currentStock: stock,
        message: 'In stock',
        statusType: StockStatusType.inStock,
      );
    }
  }

  static Future<bool> checkAvailability(String itemId, int quantity) async {
    final stock = await getItemStock(itemId);
    return stock != null && stock.currentStock >= quantity;
  }

  // Bulk stock check for multiple items
  static Future<Map<String, int>> getBulkStock(List<String> itemIds) async {
    Map<String, int> stockMap = {};

    for (String itemId in itemIds) {
      final stock = await getItemStock(itemId);
      stockMap[itemId] = stock?.currentStock ?? 0;
    }

    return stockMap;
  }
}

class StockResponse {
  final int currentStock;

  StockResponse({required this.currentStock});

  factory StockResponse.fromJson(Map<String, dynamic> json) {
    return StockResponse(
      currentStock: json['currentStock'] ?? 0,
    );
  }
}

// ADD THESE CLASSES
class StockStatus {
  final bool isAvailable;
  final int currentStock;
  final String message;
  final StockStatusType statusType;

  StockStatus({
    required this.isAvailable,
    required this.currentStock,
    required this.message,
    required this.statusType,
  });
}

enum StockStatusType {
  inStock,
  limitedStock,
  lowStock,
  outOfStock,
  unavailable,
}