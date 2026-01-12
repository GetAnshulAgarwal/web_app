import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../services/Wallet/wallet_api_services.dart';
import '../../../authentication/user_data.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<Transaction> transactions = [];
  int pointsBalance = 0;
  double cashBalance = 0.0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    print('[WalletScreen] initState called');
    fetchTransactionsFromApi();
  }

  Future<void> fetchTransactionsFromApi() async {
    print('[WalletScreen] fetchTransactionsFromApi started');
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final userData = UserData();
    final userId = userData.getUserId();
    final token = userData.getToken();

    print('[WalletScreen] UserId: $userId');
    print(
      '[WalletScreen] Token available: ${token != null && token.isNotEmpty}',
    );

    if (userId == null || userId.isEmpty) {
      print('[WalletScreen] No userId found - user not logged in');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to view wallet')),
        );
      }
      return;
    }

    try {
      print('[WalletScreen] Fetching balance...');
      // Fetch balance
      final balanceResp = await WalletApiService.getBalance(
        customerId: userId,
        token: token,
      );

      print('[WalletScreen] Balance response: ${json.encode(balanceResp)}');

      if (balanceResp['success'] == true && balanceResp['data'] != null) {
        final data = balanceResp['data'];
        print('[WalletScreen] Balance data: ${json.encode(data)}');

        setState(() {
          pointsBalance = _parseIntValue(
            data['pointsBalance'] ?? data['points'] ?? 0,
          );
          cashBalance = _parseDoubleValue(
            data['cashBalance'] ?? data['cash'] ?? 0,
          );
        });

        print(
          '[WalletScreen] Parsed balance - Points: $pointsBalance, Cash: $cashBalance',
        );
      } else {
        print(
          '[WalletScreen] Balance fetch failed or no data: ${balanceResp['message'] ?? 'Unknown error'}',
        );
        setState(() {
          errorMessage = balanceResp['message'] ?? 'Failed to load balance';
        });
      }

      print('[WalletScreen] Fetching transactions...');
      // Fetch transactions
      final txResp = await WalletApiService.getTransactions(
        customerId: userId,
        page: 1,
        limit: 50,
        token: token,
      );

      print('[WalletScreen] Transactions response: ${json.encode(txResp)}');

      if (txResp['success'] == true && txResp['data'] != null) {
        final txData = txResp['data'];
        print('[WalletScreen] Transaction data type: ${txData.runtimeType}');

        List<dynamic> txList = [];
        if (txData is List) {
          txList = txData;
        } else if (txData is Map) {
          txList = txData['transactions'] ?? txData['data'] ?? [];
        }

        print('[WalletScreen] Transaction list length: ${txList.length}');

        setState(() {
          transactions =
              txList.map((x) {
                try {
                  print(
                    '[WalletScreen] Parsing transaction: ${json.encode(x)}',
                  );
                  return Transaction.fromJson(x);
                } catch (e, st) {
                  print('[WalletScreen] Error parsing transaction: $e');
                  print(st);
                  rethrow;
                }
              }).toList();
          isLoading = false;
        });

        print(
          '[WalletScreen] Successfully parsed ${transactions.length} transactions',
        );
      } else {
        print(
          '[WalletScreen] Transaction fetch failed: ${txResp['message'] ?? 'Unknown error'}',
        );
        setState(() {
          isLoading = false;
          errorMessage = txResp['message'] ?? 'Failed to load transactions';
        });
      }
    } catch (e, st) {
      print('[WalletScreen] Exception in fetchTransactionsFromApi: $e');
      print(st);

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading wallet: $e')));
      }
    }

    print('[WalletScreen] fetchTransactionsFromApi completed');
  }

  int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _parseDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[WalletScreen] build called - isLoading: $isLoading, transactions: ${transactions.length}',
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Wallet',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
              : RefreshIndicator(
                color: Colors.black,
                onRefresh: fetchTransactionsFromApi,
                child: ListView(
                  children: [
                    const SizedBox(height: 12),

                    // Balance Card with Gradient
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 24, 144, 8),
                              Color.fromARGB(255, 48, 48, 48),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Available Balance',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.stars_rounded,
                                            color: Colors.amber[300],
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Points',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$pointsBalance',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const Text(
                                        'pts',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 60,
                                  width: 1,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.currency_rupee,
                                            color: Colors.green[300],
                                            size: 18,
                                          ),
                                          const SizedBox(width: 2),
                                          const Text(
                                            'Cash',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '₹${cashBalance.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // // Action Buttons
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(horizontal: 16),
                    //   child: Row(
                    //     children: [
                    //       Expanded(
                    //         flex: 2,
                    //         child: ElevatedButton.icon(
                    //           onPressed: () {
                    //             ScaffoldMessenger.of(context).showSnackBar(
                    //               const SnackBar(
                    //                 content: Text(
                    //                   'Add money feature coming soon',
                    //                 ),
                    //               ),
                    //             );
                    //           },
                    //           icon: const Icon(
                    //             Icons.add_circle_outline,
                    //             size: 20,
                    //           ),
                    //           label: const Text(
                    //             'Add Money',
                    //             style: TextStyle(fontWeight: FontWeight.w600),
                    //           ),
                    //           style: ElevatedButton.styleFrom(
                    //             foregroundColor: Colors.black,
                    //             backgroundColor: Colors.white,
                    //             elevation: 0,
                    //             shape: RoundedRectangleBorder(
                    //               borderRadius: BorderRadius.circular(12),
                    //               side: BorderSide(color: Colors.grey[300]!),
                    //             ),
                    //             padding: const EdgeInsets.symmetric(
                    //               vertical: 14,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //       const SizedBox(width: 12),
                    //       Expanded(
                    //         flex: 2,
                    //         child: ElevatedButton.icon(
                    //           onPressed: () {
                    //             ScaffoldMessenger.of(context).showSnackBar(
                    //               const SnackBar(
                    //                 content: Text(
                    //                   'Redeem is available from Cart during checkout',
                    //                 ),
                    //               ),
                    //             );
                    //           },
                    //           icon: const Icon(Icons.card_giftcard, size: 20),
                    //           label: const Text(
                    //             'Redeem',
                    //             style: TextStyle(fontWeight: FontWeight.w600),
                    //           ),
                    //           style: ElevatedButton.styleFrom(
                    //             foregroundColor: Colors.white,
                    //             backgroundColor: Colors.black,
                    //             elevation: 0,
                    //             shape: RoundedRectangleBorder(
                    //               borderRadius: BorderRadius.circular(12),
                    //             ),
                    //             padding: const EdgeInsets.symmetric(
                    //               vertical: 14,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 28),

                    // Transaction History Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (transactions.isNotEmpty)
                            Text(
                              '${transactions.length} total',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Error message if any
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Transactions List
                    _buildTransactionsList(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  Widget _buildTransactionsList() {
    print(
      '[WalletScreen] _buildTransactionsList called with ${transactions.length} transactions',
    );

    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your transaction history will appear here',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group transactions by date
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in transactions) {
      String dateKey = _getDateKey(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    print(
      '[WalletScreen] Grouped transactions into ${groupedTransactions.length} date groups',
    );

    List<Widget> dateGroups = [];
    groupedTransactions.forEach((date, transactions) {
      dateGroups.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                date == _getDateKey(DateTime.now()) ? 'Today' : date,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...transactions
                .map((transaction) => _buildTransactionItem(transaction))
                .toList(),
          ],
        ),
      );
    });

    return Column(children: dateGroups);
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isCredit = (transaction.points ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCredit ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? Colors.green[700] : Colors.red[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description ?? transaction.id ?? 'Transaction',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(transaction.date),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCredit ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${isCredit ? '+' : '-'}${(transaction.points ?? 0).abs()} pts',
                    style: TextStyle(
                      color: isCredit ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (transaction.amount != null && transaction.amount != 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '₹${transaction.amount!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatDateTime(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class Transaction {
  final String? id;
  final double? amount;
  final int? points;
  final DateTime date;
  final String? description;
  final String? type;

  Transaction({
    this.id,
    this.amount,
    this.points,
    required this.date,
    this.description,
    this.type,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    print('[Transaction] Parsing JSON: ${json.toString()}');

    final id =
        json['_id'] ?? json['id'] ?? json['walletId'] ?? json['transactionId'];

    final amountVal = json['amount'] ?? json['spendAmount'];
    final double? amount =
        amountVal != null
            ? (amountVal is num
                ? amountVal.toDouble()
                : double.tryParse(amountVal.toString()))
            : null;

    final pointsVal =
        json['points'] ?? json['pointsEarned'] ?? json['pointsSpent'];
    final int? points =
        pointsVal != null
            ? (pointsVal is num
                ? pointsVal.toInt()
                : int.tryParse(pointsVal.toString()))
            : null;

    final dateVal =
        json['createdAt'] ??
        json['date'] ??
        json['created_at'] ??
        json['timestamp'];
    DateTime date;
    try {
      if (dateVal is String) {
        date = DateTime.parse(dateVal);
      } else if (dateVal is int) {
        date = DateTime.fromMillisecondsSinceEpoch(dateVal);
      } else {
        date = DateTime.now();
        print('[Transaction] Could not parse date, using current time');
      }
    } catch (e) {
      print('[Transaction] Error parsing date: $e');
      date = DateTime.now();
    }

    final description = json['description'] ?? json['desc'] ?? json['note'];
    final type = json['type'] ?? json['transactionType'];

    final transaction = Transaction(
      id: id?.toString(),
      amount: amount,
      points: points,
      date: date,
      description: description?.toString(),
      type: type?.toString(),
    );

    print(
      '[Transaction] Parsed transaction: id=$id, points=$points, amount=$amount, date=$date',
    );

    return transaction;
  }

  @override
  String toString() {
    return 'Transaction(id: $id, points: $points, amount: $amount, date: $date, description: $description)';
  }
}
