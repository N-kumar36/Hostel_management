import 'dart:convert';

import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dataconnvater {
  final api = ApiService();
  Dataconnvater() {
   
    print(getUserData);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // 1. Try to get fresh data from the API first
      final profileData = await api.getProfile();

      if (profileData != null) {
        // Optional: Update local storage with the fresh data so it's ready for next time
        await prefs.setString("User", jsonEncode(profileData));
        return profileData;
      }

      // 2. Fallback: If API fails, check local SharedPreferences
      String? userStr = prefs.getString("User");
      if (userStr != null) {
        return jsonDecode(userStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }

    return null; // Return null if both API and Local Storage fail
  }
}
