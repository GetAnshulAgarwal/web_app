// services/Reward/rewards_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';
import '../../model/Reward/reward_model.dart';


class RewardsService {
  final String _apiUrl =
      'https://pos.inspiredgrow.in/vps/api/discount-coupons';

  Future<RewardsData> getRewards() async {
    try {
      final UserData _userData = UserData();
      final String? token = _userData.getToken();

      // Check if user is logged in (token exists)
      if (token == null || token.isEmpty) {
        print('RewardsService Error: No auth token found. User is not logged in.');
        throw Exception('User is not authenticated.');
      }

      // --- 3. ADD TOKEN TO HEADERS ---
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Add the token here
      };

      // 4. MAKE THE REQUEST WITH HEADERS
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: headers, // Pass the headers to the request
      );

      if (response.statusCode == 200) {
        // ... (rest of your parsing logic is the same)
        final List<dynamic> jsonList = json.decode(response.body);
        final List<DiscountCoupon> coupons =
        jsonList.map((json) => DiscountCoupon.fromJson(json)).toList();

        return _transformCouponsToRewardsData(coupons);
      } else {
        print(
            'RewardsService API Error: ${response.statusCode}, Body: ${response.body}');
        throw Exception(
            'Failed to load rewards from API: ${response.statusCode}');
      }
    } catch (e) {
      print('RewardsService Network/Parsing Error: $e');
      throw Exception('Failed to load rewards: $e');
    }
  }

  // --- HELPER FUNCTION (No changes below) ---
  RewardsData _transformCouponsToRewardsData(List<DiscountCoupon> coupons) {
    // Transform each Coupon into a RewardModel
    List<RewardModel> rewards = coupons.map((coupon) {
      // Calculate expiry days from the expiryDate
      final now = DateTime.now();
      final expiry = coupon.expiryDate;
      int expiryDays = expiry.difference(now).inDays;
      if (expiryDays < 0) expiryDays = 0;

      // Determine the UI status (the UI expects 'expired' or 'active')
      String uiStatus =
      (coupon.status == 'Active' && expiryDays > 0) ? 'active' : 'expired';

      // Create a 'detail' string from the coupon data
      String detail = coupon.description.isNotEmpty
          ? coupon.description
          : "Get ${coupon.value}${coupon.couponType == 'Fixed' ? ' Rs.' : '%'} off.";

      // --- Placeholder data for missing API fields ---
      String rewardCode = "CODE_MISSING";
      String companyName = "Inspired Grow";
      String imageUrl = 'assets/images/default_reward.png';
      List<String> howToClaim = [
        "This is a placeholder step.",
        "The new API does not provide 'howToClaim' steps."
      ];
      String termsConditions =
          "Placeholder T&Cs. The API did not provide this information.";

      // Create the RewardModel for the UI
      return RewardModel(
        id: coupon.id,
        title: coupon.occasionName,
        detail: detail,
        companyName: companyName, // Hardcoded
        expiryDays: expiryDays,
        imageUrl: imageUrl, // Hardcoded placeholder
        status: uiStatus,
        howToClaim: howToClaim, // Hardcoded
        termsConditions: termsConditions, // Hardcoded
        rewardCode: rewardCode, // Hardcoded / Missing
      );
    }).toList();

    // --- Hardcoded data for missing wrapper object ---
    return RewardsData(
      totalRewards: coupons.length,
      currencySymbol: '₹',
      sponsoredAd: SponsoredAd(
        title: 'Sponsored Ad',
        description: 'This is a placeholder ad.',
        imageUrl:
        'assets/images/sponsored_ad_placeholder.png', // Placeholder image
        backgroundColor: '#FF0000',
        actionUrl: 'https://google.com',
      ),
      rewards: rewards,
    );
  }
}