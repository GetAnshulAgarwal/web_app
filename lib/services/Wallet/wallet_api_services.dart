import 'dart:convert';
import 'package:http/http.dart' as http;

class WalletApiService {
  static const String _base = 'https://pos.inspiredgrow.in/vps';

  // -------------------------
  // Redeem Points
  // POST /my/wallet/redeem-points
  // -------------------------
  /// Redeem wallet points for the given `customerId`.
  static Future<Map<String, dynamic>> redeemPoints({
    required String customerId,
    required int spendAmount,
    required List<String> itemIds,
    String? token,
  }) async {
    final url = '$_base/my/wallet/redeem-points';
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = json.encode({
      'customerId': customerId,
      'spendAmount': spendAmount,
      'itemIds': itemIds,
    });

    try {
      _log('→ POST $url');
      _log('Headers: ${json.encode(_maskHeaders(headers))}');
      _log('Body: $body');

      final sw = Stopwatch()..start();
      final resp = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      sw.stop();

      _log('← Status ${resp.statusCode} in ${sw.elapsedMilliseconds}ms');
      _log('Response Body: ${resp.body}');

      final parsed = json.decode(resp.body);
      if (parsed is Map<String, dynamic>) return parsed;

      return {
        'success': false,
        'message': 'Invalid response from server',
        'raw': resp.body,
      };
    } catch (e, st) {
      _logError(e, st, function: 'redeemPoints');
      return {'success': false, 'message': e.toString()};
    }
  }

  // -------------------------
  // Wallet Balance
  // GET /my/wallet/balance?customerId=...
  // -------------------------
  static Future<Map<String, dynamic>> getBalance({
    required String customerId,
    String? token,
  }) async {
    final url =
        '$_base/my/wallet/balance?customerId=${Uri.encodeQueryComponent(customerId)}';
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      _log('→ GET $url');
      _log('Headers: ${json.encode(_maskHeaders(headers))}');

      final sw = Stopwatch()..start();
      final resp = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      sw.stop();

      _log('← Status ${resp.statusCode} in ${sw.elapsedMilliseconds}ms');
      _log('Response Body: ${resp.body}');

      final parsed = json.decode(resp.body);
      if (parsed is Map<String, dynamic>) return parsed;

      return {
        'success': false,
        'message': 'Invalid response from server',
        'raw': resp.body,
      };
    } catch (e, st) {
      _logError(e, st, function: 'getBalance');
      return {'success': false, 'message': e.toString()};
    }
  }

  // -------------------------
  // Wallet Transactions
  // GET /my/wallet/transactions?customerId=...&page=1&limit=20
  // -------------------------
  static Future<Map<String, dynamic>> getTransactions({
    required String customerId,
    int page = 1,
    int limit = 20,
    String? token,
  }) async {
    final query = {
      'customerId': customerId,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse(
      '$_base/my/wallet/transactions',
    ).replace(queryParameters: query);

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      _log('→ GET ${uri.toString()}');
      _log('Headers: ${json.encode(_maskHeaders(headers))}');

      final sw = Stopwatch()..start();
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      sw.stop();

      _log('← Status ${resp.statusCode} in ${sw.elapsedMilliseconds}ms');
      _log('Response Body: ${resp.body}');

      final parsed = json.decode(resp.body);
      if (parsed is Map<String, dynamic>) return parsed;

      return {
        'success': false,
        'message': 'Invalid response from server',
        'raw': resp.body,
      };
    } catch (e, st) {
      _logError(e, st, function: 'getTransactions');
      return {'success': false, 'message': e.toString()};
    }
  }

  // -------------------------
  // Logging helpers - NOW ENABLED FOR DEBUGGING
  // -------------------------
  static void _log(Object? o) {
    print('[WalletApi] $o');
  }

  static void _logError(Object e, StackTrace st, {String? function}) {
    print('[WalletApi] Error in ${function ?? 'unknown'}: $e');
    print(st);
  }

  static Map<String, String> _maskHeaders(Map<String, String> headers) {
    final out = <String, String>{};
    headers.forEach((k, v) {
      if (k.toLowerCase() == 'authorization' && v.length > 10) {
        out[k] = '${v.substring(0, 8)}***${v.substring(v.length - 6)}';
      } else {
        out[k] = v;
      }
    });
    return out;
  }
}