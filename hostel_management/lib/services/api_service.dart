import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApiService {
  // final String baseUrl = "http://10.192.6.123:5000/api";

  // Load balancer
  final String baseUrl = "https://hostel-management-vorh.vercel.app/api";

  // final String baseUrl = "http://192.168.18.253:5000/api";
  // final String baseUrl = "https://hostel-management-rouge-six.vercel.app/api";
  // final String baseUrl = "https://hostel-management-three-roan.vercel.app/api";

  // ========================================================================
  // AUTH HEADERS
  // ========================================================================

  Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString('token');

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ========================================================================
  // HOSTEL LIST
  // ========================================================================

  Future<List<dynamic>> getHostels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hostels/get'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }

      return [];
    } catch (e) {
      print("Fetch Hostels Error: $e");
      return [];
    }
  }

  // ========================================================================
  // AUTHENTICATION
  // ========================================================================

  Future<Map<String, dynamic>> updateProfilePic(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/user/update-profile-pic'),
      );

      request.headers.addAll(await _getHeaders());

      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var streamedResponse = await request.send();

      var response = await http.Response.fromStream(streamedResponse);

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'],
          "data": data['data'],
        };
      }

      return {"success": false, "message": data['message'] ?? "Upload failed"};
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString("token", data['token']);
      }

      return data;
    } catch (e) {
      print("Login error: $e");

      return {
        "success": false,
        "message": "Network error occurred. Please try again.",
      };
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final Map<String, dynamic> profile = data.containsKey('user')
            ? data['user']
            : data;

        if (data.containsKey('token') && data['token'] != null) {
          final String refreshedToken = data['token'].toString();

          SharedPreferences prefs = await SharedPreferences.getInstance();

          await prefs.setString("token", refreshedToken);

          debugPrint("Auth token refreshed and saved successfully on startup.");
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString("User", jsonEncode(profile));

        return profile;
      } else {
        debugPrint(
          "Profile Fetch Failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Get Profile Exception: $e");
    }

    return null;
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> userData,
  ) async {
    print("update profile data $userData");

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(userData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print("Update Profile Error: $e");

      return {
        "success": false,
        "message": "Network error occurred. Please try again.",
      };
    }
  }

  Future<Map<String, dynamic>> sendOtp(String email, String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "phone": phone}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print("Send OTP Error: $e");

      return {
        "success": false,
        "message": "Network error occurred. Please try again.",
      };
    }
  }

  Future<bool> sendOtpForgetPass(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/forget-otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetPasswordFunction(
    String email,
    String password,
    String otp,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/auth/forget-pass'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password, "otp": otp}),
      );

      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print("Register Error: $e");

      return {
        "success": false,
        "message": "Network error occurred. Please try again.",
      };
    }
  }

  // ========================================================================
  // HISTORY
  // ========================================================================

  Future<Map<String, dynamic>> getVoteHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vote/history'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Failed to load history');
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // MEAL CYCLE
  // ========================================================================

  Future<Map<String, dynamic>> getMealCycleDateBounds() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/finance/meal-cycle-bounds"),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint("API Error reading system cycle definitions: $e");

      rethrow;
    }
  }

  // ========================================================================
  // WHOLE MESS MEAL SUMMARY
  // ========================================================================
  //
  // IMPORTANT:
  // This is NOT based on individual student votes.
  //
  // It calculates the entire mess cycle:
  //
  // Total:
  //   Number of meal occurrences planned in the cycle.
  //
  // Prepared:
  //   Number of meal occurrences marked isPrepared = true.
  //
  // Left:
  //   Total - Prepared
  //
  // Student missing/voting/cancelled status does NOT affect this.
  //
  // Backend:
  // GET /api/meals/whole-mess-summary
  //
  // Query:
  // startDateStr=DD/MM/YYYY
  // endDateStr=DD/MM/YYYY
  //
  // ========================================================================

  Future<Map<String, dynamic>> getWholeMessMealSummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/meals/whole-mess-summary').replace(
        queryParameters: {'startDateStr': startDate, 'endDateStr': endDate},
      );

      debugPrint("Whole Mess Summary URL: $uri");

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      throw Exception(
        decoded['message'] ?? 'Failed to load whole-mess meal summary',
      );
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      debugPrint("Whole Mess Summary Error: $e");

      rethrow;
    }
  }

  // ========================================================================
  // FINANCE
  // ========================================================================

  Future<Map<String, dynamic>> getFinanceAuditReport(
    String startDate,
    String endDate,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/finance/audit-statement"
          "?startDateStr=$startDate"
          "&endDateStr=$endDate",
        ),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint("Finance Audit Report Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getVoteSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meal-plan/getAllSubscriptions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Failed to load history');
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // MEAL PACKAGES
  // ========================================================================

  Future<Map<String, dynamic>> getmealPackages() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/meal-plan/get"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception("Failed to load packages");
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> selectPackage(String planId) async {
    try {
      String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

      final response = await http.post(
        Uri.parse("$baseUrl/meal-plan/select"),
        headers: await _getHeaders(),
        body: json.encode({"planId": planId, "currentMonth": currentMonth}),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200) {
        return result;
      }

      throw Exception(result['message'] ?? "Failed to Select Package");
    } catch (e) {
      debugPrint("Select Package Error: $e");

      rethrow;
    }
  }

  // ========================================================================
  // COMPLAINTS
  // ========================================================================

  Future<Map<String, dynamic>> createComplaintWithImage({
    required String requestType,
    required String category,
    required String description,
    DateTime? meetingDate,
    String? meetingTime,
    File? image,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complains/create'),
      );

      request.headers.addAll(await _getHeaders());

      // -------------------------------------------------------------------------
      // BASIC COMPLAINT DATA
      // -------------------------------------------------------------------------

      request.fields['requestType'] = requestType;
      request.fields['category'] = category;
      request.fields['description'] = description;

      // -------------------------------------------------------------------------
      // MEETING DATA
      // -------------------------------------------------------------------------

      if (meetingDate != null) {
        request.fields['meetingDate'] = meetingDate.toIso8601String();
      }

      if (meetingTime != null && meetingTime.trim().isNotEmpty) {
        request.fields['meetingTime'] = meetingTime;
      }

      // -------------------------------------------------------------------------
      // IMAGE
      // -------------------------------------------------------------------------

      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }

      // -------------------------------------------------------------------------
      // SEND REQUEST
      // -------------------------------------------------------------------------

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      // -------------------------------------------------------------------------
      // RESPONSE
      // -------------------------------------------------------------------------

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server returned an empty response.',
        };
      }

      final decoded = json.decode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'success': false, 'message': 'Invalid server response.'};
    } catch (e) {
      debugPrint('createComplaintWithImage error: $e');

      rethrow;
    }
  }

  // ========================================================================
  // MEAL STATUS
  // ========================================================================

  Future<Map<String, dynamic>> getMealStatus(String studentOd) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/meals/Status/$studentOd'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception('Failed to load history');
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // FINES
  // ========================================================================

  Future<List<dynamic>> getMyFines() async {
    final response = await http.get(
      Uri.parse('$baseUrl/fines/my-fines'),
      headers: await _getHeaders(),
    );

    final data = json.decode(response.body);

    return data['data'];
  }

  Future<Map<String, dynamic>> uploadPaymentProof(
    String fineId,
    File imageFile,
  ) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/fines/pay/$fineId'),
    );

    request.headers.addAll(await _getHeaders());

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    var streamedResponse = await request.send();

    var response = await http.Response.fromStream(streamedResponse);

    return json.decode(response.body);
  }

  // ========================================================================
  // UPI
  // ========================================================================

  Future<bool> saveUpiDetails(Map<String, String> data) async {
    final response = await http.post(
      Uri.parse("$baseUrl/upi/save"),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>?> getManagerUpi() async {
    final response = await http.get(
      Uri.parse("$baseUrl/upi/get"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['data'];
    }

    return null;
  }

  // ========================================================================
  // GUEST MEALS
  // ========================================================================

  Future<Map<String, dynamic>> requestGuestMeal({
    required int guestCount,
    required String mealDate,
    required String mealTime,
    required String guestItemPreference,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guest-meals/request'),
        headers: await _getHeaders(),
        body: jsonEncode({
          "guestCount": guestCount,
          "mealDate": mealDate,
          "mealTime": mealTime,
          "guestItemPreference": guestItemPreference,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'] ?? "Request sent successfully",
        };
      }

      if (response.statusCode == 403) {
        return {
          "success": false,
          "message": data['message'] ?? "Blocked by pending fines",
        };
      }

      return {
        "success": false,
        "message": data['message'] ?? "Server validation exception error",
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  Future<Map<String, dynamic>> cancelGuestMealRequest(String requestId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/guest-meals/cancel/$requestId"),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message']};
      }

      return {
        "success": false,
        "message": data['message'] ?? "Failed to cancel",
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  Future<List<dynamic>> getMyGuestMealRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guest-meals/my-requests'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return data['data'];
      }

      return [];
    } catch (e) {
      debugPrint("API Error: $e");

      return [];
    }
  }

  // ========================================================================
  // VOTING
  // ========================================================================

  Future<List<dynamic>> checkUserVotes(List<String> mealIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vote/check-status'),
      headers: await _getHeaders(),
      body: jsonEncode({"mealIds": mealIds}),
    );

    final data = jsonDecode(response.body);

    return data['userVotes'] ?? [];
  }

  Future<Map<String, dynamic>> fetchWeeklyMeals() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/meals/week"), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return convertMealsToWeekly(data['meals'] ?? []);
      }

      throw Exception('Server Error: ${response.statusCode}');
    } catch (e) {
      print("Weekly Meals Error: $e");

      rethrow;
    }
  }

  Map<String, dynamic> convertMealsToWeekly(List meals) {
    final Map<String, dynamic> weekly = {};

    for (var meal in meals) {
      weekly[meal['date']] = {
        "_id": meal["_id"],
        'morning': meal['morning'],
        'night': meal['night'],
      };
    }

    return weekly;
  }

  Future<Map<String, dynamic>> postVote(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/vote/post"),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "Endpoint not found"};
      }

      throw Exception("Server Error : ${response.statusCode}");
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      print("Error Setting Routine: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelVote(
    String mealId,
    String timeSlot,
  ) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/vote/cancel"),
      headers: await _getHeaders(),
      body: jsonEncode({"mealId": mealId, "timeSlot": timeSlot}),
    );

    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> checkVoteStatus(String mealId) async {
    print("$baseUrl/vote/status/$mealId");

    final response = await http.patch(
      Uri.parse("$baseUrl/vote/status/$mealId"),
      headers: await _getHeaders(),
    );

    return json.decode(response.body);
  }

  // ========================================================================
  // PAYMENT HISTORY
  // ========================================================================

  Future<Map<String, dynamic>> getAllPaymentHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/all-payment-history'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception("Failed to load payment history");
    }
  }

  // ========================================================================
  // NOTIFICATIONS
  // ========================================================================

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        "success": false,
        "message": decoded['message'] ?? "Failed to load notifications",
        "data": [],
      };
    } on SocketException {
      return {
        "success": false,
        "message": "No Internet Connection",
        "data": [],
      };
    } catch (e) {
      debugPrint("Get Notifications Error: $e");

      return {
        "success": false,
        "message": "Failed to load notifications",
        "data": [],
      };
    }
  }

  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: await _getHeaders(),
      );

      final decoded = _decodeResponse(response);

      return response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true;
    } catch (e) {
      debugPrint("Mark Notification Read Error: $e");

      return false;
    }
  }

  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/mark-all-as-read'),
        headers: await _getHeaders(),
      );

      final decoded = _decodeResponse(response);

      return response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true;
    } catch (e) {
      debugPrint("Mark All Notifications Read Error: $e");

      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: await _getHeaders(),
      );

      final decoded = _decodeResponse(response);

      return response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true;
    } catch (e) {
      debugPrint("Delete Notification Error: $e");

      return false;
    }
  }

  // ========================================================================
  // CREATE MEAL SERVED NOTIFICATION
  // ========================================================================
  //
  // Called by the manager/serve-meal flow after a student's meal
  // has actually been marked as served.
  //
  // Backend:
  // POST /api/notifications/meal-served
  //
  // This creates a "Take Your Meal" notification for the student.
  //
  // ========================================================================

  Future<Map<String, dynamic>> createMealServedNotification({
    required String studentId,
    required String meal,
    required String timeSlot,
    required String mealDate,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/notifications/meal-served'),
            headers: await _getHeaders(),
            body: jsonEncode({
              "studentId": studentId,
              "meal": meal,
              "timeSlot": timeSlot,
              "mealDate": mealDate,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = _decodeResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        "success": false,
        "message":
            decoded['message'] ?? "Failed to create meal served notification",
      };
    } on SocketException {
      return {"success": false, "message": "No Internet Connection"};
    } catch (e) {
      debugPrint("Create Meal Served Notification Error: $e");

      return {
        "success": false,
        "message": "Failed to create meal served notification",
      };
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final body = response.body.trim();

      if (body.isEmpty) {
        return {
          "success": response.statusCode >= 200 && response.statusCode < 300,
        };
      }

      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        "success": response.statusCode >= 200 && response.statusCode < 300,
        "data": decoded,
      };
    } catch (e) {
      debugPrint("Response Decode Error: $e");

      return {"success": false, "message": "Invalid server response"};
    }
  }

  // ========================================================================
  // MANAGER ACCESS CONTROL
  // ========================================================================

  Future<Map<String, dynamic>> getDashboardCounts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/managers/dashboard-counts'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw Exception("Failed to fetch dashboard counts");
    } catch (e) {
      throw Exception("API Error: $e");
    }
  }

  Future<List<dynamic>> getPendingStudent() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/managers/pending'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedBody = json.decode(response.body);

        if (decodedBody is Map && decodedBody.containsKey('data')) {
          return decodedBody['data'] as List<dynamic>;
        }

        return [];
      }

      if (response.statusCode == 404) {
        return [];
      }

      throw Exception("Server Error: ${response.statusCode}");
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      throw Exception("Unexpected Error: $e");
    }
  }

  Future<Map<String, dynamic>> approveStudent(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/managers/approve/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? 'Failed to approve student');
    } catch (e) {
      print("Error approving student: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> rejectStudent(String id) async {
    try {
      final response = await http.patch(
        Uri.parse("$baseUrl/managers/reject/$id"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? "Failed to Reject Student");
    } catch (e) {
      print("Error Reject Student : $e");

      rethrow;
    }
  }

  Future<List<dynamic>> getAllHostelStudent() async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/managers/get-student"),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      if (response.statusCode == 404) {
        return [];
      }

      throw Exception("Server Error : ${response.statusCode}");
    } on SocketException {
      throw const SocketException("No Internal Connection");
    } catch (e) {
      print("Error Fetch student $e");

      rethrow;
    }
  }

  // ========================================================================
  // ROUTINE
  // ========================================================================

  Future<Map<String, dynamic>> getroutine() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/managers/get-routine"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "No routine found"};
      }

      throw Exception("Server Error : ${response.statusCode}");
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      print("Error Fetching Routine: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> setroutine(
    Map<String, dynamic> routineData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/managers/create-routine"),
        headers: await _getHeaders(),
        body: json.encode(routineData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "Endpoint not found"};
      }

      throw Exception("Server Error : ${response.statusCode}");
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      print("Error Setting Routine: $e");

      rethrow;
    }
  }

  // ========================================================================
  // MEAL MANAGEMENT
  // ========================================================================

  Future<Map<String, dynamic>> createMeal(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/meals/create'),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? 'Failed to create meal plan');
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      print("Error creating meal: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAllMeals({
    String? startDate,
    String? endDate,
  }) async {
    try {
      String urlString = '$baseUrl/meals/all';

      if (startDate != null && endDate != null) {
        urlString +=
            '?startDateStr=$startDate'
            '&endDateStr=$endDate';
      }

      print("Date $startDate $endDate $urlString");

      final response = await http
          .get(Uri.parse(urlString), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      final decodedError = json.decode(response.body);

      throw Exception(
        decodedError['message'] ?? 'Failed to load meals cycle from backend',
      );
    } on SocketException {
      throw const SocketException("No Internet Connection detected");
    } catch (e) {
      debugPrint("API Service Layer Exception caught inside getAllMeals: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateMeal(
    String mealId,
    Map<String, dynamic> payload,
  ) async {
    try {
      print("payload $payload");

      final response = await http.put(
        Uri.parse('$baseUrl/meals/update/$mealId'),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? 'Failed to update meal');
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> autoGenerateMeals(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/meals/auto-generate'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception("Failed to auto generate meals");
    }
  }

  Future<Map<String, dynamic>> getDetailedVotesByDate(
    String mealDate,
    String timeSlot,
  ) async {
    try {
      final queryParams = {
        'mealDate': mealDate.toString(),
        'timeSlot': timeSlot.toLowerCase(),
      };

      final uri = Uri.parse(
        '$baseUrl/vote/get-votes',
      ).replace(queryParameters: queryParams);

      print("URL $uri");

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      if (response.statusCode == 404) {
        return {"success": false, "data": [], "message": "No meal found"};
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? 'Failed to fetch votes');
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      debugPrint("Detailed Votes Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateServeStatus(
    String? voteId,
    String studentId,
    String mealDate,
    String timeSlot,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vote/serve'),
      headers: await _getHeaders(),
      body: jsonEncode({
        "voteId": voteId,
        "studentId": studentId,
        "mealDate": mealDate,
        "timeSlot": timeSlot,
      }),
    );

    return jsonDecode(response.body);
  }

  // ========================================================================
  // GUEST MEAL MANAGEMENT
  // ========================================================================

  Future<Map<String, dynamic>> updateGuestMealStatus(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/guest-meals/update"),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );

      final decodedData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": decodedData['message'] ?? "Status updated",
        };
      }

      return {
        "success": false,
        "message":
            decodedData['message'] ??
            "Failed to update status balance variables",
      };
    } catch (e) {
      debugPrint("Update Guest Status Exception: $e");

      return {"success": false, "message": "Connection error: $e"};
    }
  }

  Future<Map<String, dynamic>> getHostelGuestRequests() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/guest-meals/all"),
        headers: await _getHeaders(),
      );

      final decodedData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": decodedData['data'] ?? []};
      }

      return {
        "success": false,
        "data": [],
        "message": decodedData["message"] ?? "Failed to fetch requests",
      };
    } catch (e) {
      debugPrint("Fetch Guest Requests Error: $e");

      return {
        "success": false,
        "data": [],
        "message": "Connection loss or pipeline parsing failure: $e",
      };
    }
  }

  // ========================================================================
  // BILL / FINE MANAGEMENT
  // ========================================================================

  Future<List<dynamic>> getBillsByDateRange({
    required String startDateStr,
    required String endDateStr,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              "$baseUrl/fines/pending"
              "?startDateStr=$startDateStr"
              "&endDateStr=$endDateStr",
            ),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'] ?? [];
      }

      return [];
    } catch (e) {
      debugPrint("Error fetching cycle bills: $e");

      return [];
    }
  }

  Future<bool> updateBillStatus(
    String billId,
    String status, {
    String? paymentMethod,
  }) async {
    try {
      final Map<String, dynamic> payload = {"status": status};

      if (paymentMethod != null) {
        payload["paymentMethod"] = paymentMethod;
      }

      final response = await http.put(
        Uri.parse("$baseUrl/fines/$billId/status"),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating status: $e");

      return false;
    }
  }

  Future<bool> saveSettingData(Map<String, dynamic> fullConfig) async {
    try {
      print("Saving Setting Data: $fullConfig");

      final response = await http.post(
        Uri.parse("$baseUrl/managers/sattingData"),
        headers: await _getHeaders(),
        body: json.encode({
          "finePrices": fullConfig['finePrices'],
          "plans": fullConfig['plans'],
          "upi": fullConfig['upi'],
        }),
      );

      print("saveMealPriceTable $fullConfig \nresponse $response");

      return response.statusCode == 200;
    } catch (e) {
      print("Error saving setting data: $e");

      return false;
    }
  }

  Future<Map<String, dynamic>?> getSattingData() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/managers/sattingData"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ========================================================================
  // STUDENTS
  // ========================================================================

  Future<List<dynamic>?> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/all-students"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      }

      return null;
    } catch (e) {
      debugPrint("getAllStudents Error: $e");

      return null;
    }
  }

  Future<bool> createIndividualFine(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/fines/create"),
        headers: await _getHeaders(),
        body: json.encode(data),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("createIndividualFine Error: $e");

      return false;
    }
  }

  Future<Map<String, dynamic>> getStudentSummary(
    String studentId, {
    String? startDateStr,
    String? endDateStr,
  }) async {
    try {
      String urlPath = '$baseUrl/managers/Status/$studentId';

      if (startDateStr != null && endDateStr != null) {
        urlPath +=
            '?startDateStr=$startDateStr'
            '&endDateStr=$endDateStr';
      }

      print("GetSumary date $startDateStr $endDateStr URi $urlPath");

      final response = await http.get(
        Uri.parse(urlPath),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(
        errorData['message'] ??
            'Failed to load student summary analytics metrics.',
      );
    } catch (e) {
      debugPrint("API Execution Error inside getStudentSummary: $e");

      rethrow;
    }
  }

  // ========================================================================
  // COMPLAINT MANAGEMENT
  // ========================================================================

  Future<List<dynamic>> getComplains() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/complains/all"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return data['complains'] ?? [];
      }

      throw Exception("Failed to load complains");
    } catch (e) {
      debugPrint("Get Complains Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateComplainStatus(
    String complainId,
    String status,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/complains/$complainId/status"),
        headers: await _getHeaders(),
        body: json.encode({"status": status}),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint("Update Complain Error: $e");

      rethrow;
    }
  }

  // ========================================================================
  // MANAGER SUBSCRIPTIONS
  // ========================================================================

  Future<List<dynamic>> getManagerSubscriptions() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/meal-plan/manager/getAllSubscriptions"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return data['data'] ?? [];
      }

      throw Exception("Failed to load subscriptions");
    } catch (e) {
      debugPrint("Get Manager Subscriptions Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSubscriptionByManager(
    String subId,
    String planId,
    String status,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/meal-plan/manager/updateSubscription/$subId"),
        headers: await _getHeaders(),
        body: json.encode({"planId": planId, "status": status}),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint("Update Sub Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteSubscriptionByManager(String subId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/meal-plan/manager/deleteSubscription/$subId"),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint("Delete Sub Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> compileAllStudentSubscriptions() async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/meal-plan/manager/compile-all"),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      final decodedError = json.decode(response.body);

      throw Exception(
        decodedError['message'] ??
            'Failed to batch compile student subscriptions',
      );
    } on SocketException {
      throw const SocketException("No Internet Connection detected");
    } catch (e) {
      debugPrint(
        "API Service Exception caught inside compileAllStudentSubscriptions: $e",
      );

      rethrow;
    }
  }

  Future<bool> updateFineStatus(String fineId, String status) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/fines/$fineId/status"),
        headers: await _getHeaders(),
        body: json.encode({"status": status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Update Fine Status Error: $e");

      return false;
    }
  }

  Future<bool> deleteFine(String fineId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/fines/$fineId"),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete Fine Error: $e");

      return false;
    }
  }

  Future<Map<String, dynamic>> convertPackToGuestMeal(String fineId) async {
    try {
      final url = Uri.parse("$baseUrl/fines/$fineId/convert-to-guest");

      final headers = await _getHeaders();

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({}),
      );

      final Map<String, dynamic> resData = json.decode(response.body);

      if (response.statusCode == 200 && resData['success'] == true) {
        return {
          "success": true,
          "message": resData['message'] ?? "Converted successfully!",
        };
      }

      return {
        "success": false,
        "message": resData['message'] ?? "Failed to convert meal package.",
      };
    } catch (e) {
      return {"success": false, "message": "Network error: ${e.toString()}"};
    }
  }

  Future<bool> convertFineToSub(String fineId, String planId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/fines/$fineId/convert-to-subscription"),
        headers: await _getHeaders(),
        body: json.encode({"planId": planId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Convert Fine Error: $e");

      return false;
    }
  }

  // ========================================================================
  // SHOPPING LIST
  // ========================================================================

  Future<Map<String, dynamic>> getShoppingList({
    required String startDateStr,
    required String endDateStr,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/shopping-list"
          "?startDateStr=$startDateStr"
          "&endDateStr=$endDateStr",
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      throw Exception("Failed to load shopping list");
    } catch (e) {
      debugPrint("Get Shopping List Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateShoppingList(
    String itemId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/shopping-list/$itemId"),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? "Failed to update item");
    } catch (e) {
      debugPrint("Update Shopping List Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> addShoppingListItem(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/shopping-list"),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }

      final errorData = json.decode(response.body);

      throw Exception(errorData['message'] ?? "Failed to add item");
    } catch (e) {
      debugPrint("Add Shopping List Item Error: $e");

      rethrow;
    }
  }

  Future<bool> deleteShoppingListItem(String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/shopping-list/$itemId"),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete Shopping List Item Error: $e");

      return false;
    }
  }

  // ========================================================================
  // ADMIN APIs
  // ========================================================================

  Future<Map<String, dynamic>> updateHostelStudentProfile(
    String studentId,
    Map<String, dynamic> updatedPayload,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/user/profile/$studentId"),
        headers: await _getHeaders(),
        body: json.encode(updatedPayload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decodedData = json.decode(response.body);

        return decodedData;
      }

      final errorBody = json.decode(response.body);

      throw Exception(
        errorBody['message'] ?? "Server error: ${response.statusCode}",
      );
    } catch (e) {
      debugPrint("updateHostelStudentProfile Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteHostelUser(String studentId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/user/profile/$studentId"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decodedData = json.decode(response.body);

        return decodedData;
      }

      final errorBody = json.decode(response.body);

      throw Exception(
        errorBody['message'] ?? "Failed to delete user: ${response.statusCode}",
      );
    } catch (e) {
      debugPrint("deleteHostelUser Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStudentById(String studentId) async {
    print("Student Id $studentId");

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/user/$studentId"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decodedData = json.decode(response.body);

        return decodedData;
      }

      final errorBody = json.decode(response.body);

      throw Exception(
        errorBody['message'] ??
            "Failed to fetch student profile: ${response.statusCode}",
      );
    } catch (e) {
      debugPrint("getStudentById Error: $e");

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStudentFines(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/fines/$studentId"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decodedData = json.decode(response.body);

        return decodedData;
      }

      final errorBody = json.decode(response.body);

      throw Exception(
        errorBody['message'] ??
            "Failed to fetch student fines: ${response.statusCode}",
      );
    } catch (e) {
      debugPrint("getStudentFines Error: $e");

      rethrow;
    }
  }

  Future<List<dynamic>?> getAllStudentsMnager() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/managers/getallStudent"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body)['data'];
      }

      return null;
    } catch (e) {
      debugPrint("GetAllStudent Error: $e");

      return null;
    }
  }
}
