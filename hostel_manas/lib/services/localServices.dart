import 'dart:convert';
import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalService {
  final api = ApiService();

  // Profile Logic: Cache first, then API fallback
  Future<Map<String, dynamic>?> fetchProfile({
    bool forceRefresh = false,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // If not forcing a refresh, try to return cached data
      if (!forceRefresh) {
        String? userStr = prefs.getString("User");
        if (userStr != null) {
          return jsonDecode(userStr);
        }
      }

      // Fallback to API if cache is empty or forceRefresh is true
      final freshData = await api.getProfile();
      // Note: api.getProfile already saves to SharedPreferences in the code above
      return freshData;
    } catch (e) {
      debugPrint("Error fetching profile in L_S: $e");
      return null;
    }
  }

  //  Stats Logic: Calculate and return processed data
  Future<Map<String, int>> fetchAndCalculateMealStats() async {
    try {
      final response = await api.getVoteHistory();
      int total = 0;
      int consumed = 0;

      if (response['success'] == true) {
        List<dynamic> history = response['history'];
        for (var meal in history) {
          // Logic: Count only non-cancelled meals as Total
          if (meal['isCancelled'] == false) total++;
          // Logic: Count only served meals as Consumed
          if (meal['isServed'] == true) consumed++;
        }
      }
      return {"total": total, "consumed": consumed};
    } catch (e) {
      debugPrint("Error calculating stats in L_S: $e");
      return {"total": 0, "consumed": 0};
    }
  }

  //  Useful helper to clear data on Logout
  Future<void> clearCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("User");
  }
}
