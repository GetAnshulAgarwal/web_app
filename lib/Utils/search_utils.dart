import 'package:flutter/material.dart';

import '../model/home/product_model.dart';

class SearchUtils {
  // Highlight search terms in text
  static TextSpan buildHighlightedText(String text, String searchQuery) {
    if (searchQuery.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = searchQuery.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery, start);

    while (index != -1) {
      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ));
      }

      // Add the highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.red,
          backgroundColor: Color(0xFFFFE4E4),
        ),
      ));

      start = index + searchQuery.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  // Safe type conversions
  static int safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.isNaN ? 0 : value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value.isNaN ? 0.0 : value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static bool productNeedsPriceFetch(Product product) {
    final salesPrice = safeToDouble(product.salesPrice);
    final mrp = safeToDouble(product.mrp);
    return salesPrice <= 0 && mrp <= 0;
  }
}