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
      // Fetch history from API
      final response = await api.getVoteSummary();

      // Initialize all counters
      int total = 0;
      int consumed = 0;
      int votedCount = 0;
      int guestTotal = 0;

      int veg = 0;
      int egg = 0;
      int paneer = 0;
      int chicken = 0;
      int fish = 0;
      int mutton = 0;

      if (response['success'] == true) {
        List<dynamic> history = response['history'];

        for (var meal in history) {
          // 1. Total available meals (not cancelled)
          if (meal['isCancelled'] == false) {
            total++;
          }

          // 2. Count Total Guests
          if (meal['guestCount'] != null) {
            guestTotal += (meal['guestCount'] as num).toInt();
          }

          // 3. Count Consumed (Served) meals
          if (meal['isServed'] == true) {
            consumed++;
          }

          // 4. Count Voted meals AND breakdown the Menu Items they voted for
          if (meal['voted'] == true) {
            votedCount++;

            String item = meal['menuItem'].toString().toLowerCase();
            switch (item) {
              case 'veg':
                veg++;
                break;
              case 'egg':
                egg++;
                break;
              case 'paneer':
                paneer++;
                break;
              case 'chicken':
                chicken++;
                break;
              case 'fish':
                fish++;
                break;
              case 'mutton':
                mutton++;
                break;
            }
          }
        }
      }

      // Return EVERYTHING
      return {
        "total": total,
        "consumed": consumed,
        "voted": votedCount,
        "guests": guestTotal,
        "veg": veg,
        "egg": egg,
        "paneer": paneer,
        "chicken": chicken,
        "fish": fish,
        "mutton": mutton,
      };
    } catch (e) {
      debugPrint("Error calculating stats: $e");
      // Return safe default values if API fails
      return {
        "total": 0,
        "consumed": 0,
        "voted": 0,
        "guests": 0,
        "veg": 0,
        "egg": 0,
        "paneer": 0,
        "chicken": 0,
        "fish": 0,
        "mutton": 0,
      };
    }
  }

  //  Useful helper to clear data on Logout
  Future<void> clearCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("User");
  }


  // 
}
