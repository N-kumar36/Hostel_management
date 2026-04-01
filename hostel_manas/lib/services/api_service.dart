import 'dart:convert';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Assuming this contains your convertMealsToWeekly logic

class ApiService {
  // final String baseUrl = "https://hostel-management-3e61.onrender.com/api";
  // final String baseUrl = "http://192.168.0.39:5000/api";
  // final String baseUrl = "http://192.168.18.253:5000/api";
  final String baseUrl = "https://hostel-management-rouge-six.vercel.app/api";

  // Helper to get headers with Bearer token
  Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ========================== HOSTEL LIST ========================== //

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

  // ========================= AUTHENTICATION ======================== //

  // ser profile pic
  // Add this to your ApiService class
  Future<Map<String, dynamic>> updateProfilePic(File imageFile) async {
    try {
      // URL matches the backend route we created earlier
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/user/update-profile-pic'),
      );

      // Add authentication headers
      request.headers.addAll(await _getHeaders());

      // Attach the image file
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'],
          "data": data['data'],
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? "Upload failed",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("token", data['token']);
          return data;
        }
      }
      return null;
    } catch (e) {
      print("Login error: $e");
      return null;
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

        // Handle common API patterns: data['user'] or just data
        final Map<String, dynamic> profile = data.containsKey('user')
            ? data['user']
            : data;

        // Update the local cache immediately upon successful fetch
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

  Future<bool> sendOtp(String email, String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "phone": phone}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
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

  Future<bool> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Register Error: $e");
      return false;
    }
  }

  // get history
  Future<Map<String, dynamic>> getVoteHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vote/history'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
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
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      rethrow;
    }
  }

  // get meal packages
  Future<Map<String, dynamic>> getmealPackages() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/meal-plan/get"), // Adjust route if needed
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Return the full map so we can access both 'packages' and 'activePackageId'
        return json.decode(response.body);
      } else {
        throw Exception("Failed to load packages");
      }
    } catch (e) {
      rethrow;
    }
  }

  // select meal packages
  Future<Map<String, dynamic>> selectPackage(String planId) async {
    try {
      String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

      final response = await http.post(
        Uri.parse("$baseUrl/meal-plan/select"),
        headers: await _getHeaders(),
        body: json.encode({
          "planId": planId, // Matches backend controller variable
          "currentMonth": currentMonth, // Matches backend requirement
        }),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200) {
        return result;
      } else {
        throw Exception(result['message'] ?? "Failed to Select Package");
      }
    } catch (e) {
      debugPrint("Select Package Error: $e");
      rethrow;
    }
  }

  // complain create
  Future<Map<String, dynamic>> createComplaintWithImage(
    String category,
    String description,
    File? imageFile,
  ) async {
    try {
      // 1. Create the request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complains/create'),
      );

      // 2. Add Auth Headers
      request.headers.addAll(await _getHeaders());

      // 3. Add Text Fields
      request.fields['category'] = category;
      request.fields['description'] = description;

      // 4. Add Image File (if selected)
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image', // This key must match the backend 'upload.single' key
            imageFile.path,
          ),
        );
      }

      // 5. Send and handle response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return json.decode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // get meal status ech student
  Future<Map<String, dynamic>> getMealStatus(String studentOd) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/meals/Status/$studentOd'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fetching Student Fines
  Future<List<dynamic>> getMyFines() async {
    final response = await http.get(
      Uri.parse('$baseUrl/fines/my-fines'),
      headers: await _getHeaders(),
    );
    final data = json.decode(response.body);
    return data['data'];
  }

  // Uploading Payment Proof
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

  // get upi details
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

  // guest meal
  // Fetching and sending guest meal requests
  Future<Map<String, dynamic>> requestGuestMeal({
    required int guestCount,
    required String mealDate,
    required String mealTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/guest-meals/request'),
        headers: await _getHeaders(), // Ensure this includes your JWT token
        body: jsonEncode({
          "guestCount": guestCount,
          "mealDate": mealDate,
          "mealTime": mealTime,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {"success": true, "message": "Request sent successfully"};
      } else if (response.statusCode == 403) {
        // This is the error from our backend fine check
        return {
          "success": false,
          "message": data['message'] ?? "Blocked by pending fines",
        };
      } else {
        return {"success": false, "message": data['message'] ?? "Server error"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // Add this to your ApiService class
  Future<Map<String, dynamic>> cancelGuestMealRequest(String requestId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/guest-meals/cancel/$requestId"),
        headers:
            await _getHeaders(), // Must include 'Authorization': 'Bearer <token>'
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message']};
      } else {
        return {
          "success": false,
          "message": data['message'] ?? "Failed to cancel",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  Future<List<dynamic>> getMyGuestMealRequests() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/guest-meals/my-requests',
        ), // Ensure this route exists in your backend
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

  // ====================== MEAL MANAGEMENT ====================== //
  // voting apis
  //----------------------------------------------------------------------//
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
        // Logic fix: pass the 'meals' list directly
        return convertMealsToWeekly(data['meals'] ?? []);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      print("Weekly Meals Error: $e");
      rethrow;
    }
  }

  Map<String, dynamic> convertMealsToWeekly(List meals) {
    final Map<String, dynamic> weekly = {};

    for (var meal in meals) {
      // FIX 1: Use "_id" instead of "id" to match your Postman JSON
      // FIX 2: Store the entire meal object but keyed by date for easy lookup
      weekly[meal['date']] = {
        "_id": meal["_id"],
        'morning': meal['morning'],
        'night': meal['night'],
      };
    }
    return weekly;
  }

  //------------------------------------------------------------------------------//
  Future<Map<String, dynamic>> postVote(Map<String, dynamic> payload) async {
    // print("payload $payload");
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
    // print("cancel $mealId  $timeSlot");
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


// Inside your api_service.dart
  Future<Map<String, dynamic>> getAllPaymentHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/all-payment-history'), // Check your exact route path
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception("Failed to load payment history");
    }
  }
 
 Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'), // Update with your route
        headers: await _getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception("Failed to load notifications");
    }
  }

  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/mark-all-as-read'), // Update with your route
        headers: await _getHeaders(),
      );
      final decoded = jsonDecode(response.body);
      return decoded['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // =====================  MANAGER ACCESS CONTROL ===================================//

  Future<Map<String, dynamic>> getDashboardCounts() async {
    try {
      // Replace with your actual route URL
      final response = await http.get(
        Uri.parse('$baseUrl/managers/dashboard-counts'),
        headers:
            await _getHeaders(), // Assuming you have a method attaching auth tokens
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to fetch dashboard counts");
      }
    } catch (e) {
      throw Exception("API Error: $e");
    }
  }

  // pending Student
  Future<List<dynamic>> getPendingStudent() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/managers/pending'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      // Check for 404 and return an empty list so FutureBuilder doesn't show an error
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
        // Ensure this URL matches your backend route exactly
        Uri.parse('$baseUrl/managers/approve/$id'),
        // You MUST include headers for the verifyToken middleware to work
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Decode and return the success message from your Node.js controller
        return json.decode(response.body);
      } else {
        // Decode error message from backend if possible
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to approve student');
      }
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
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? "Failed to Reject Student");
      }
    } catch (e) {
      print("Error Reject Student : $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------//
  // all student
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

  //======================================  Create meal ====================//
  /// Fetches the current weekly routine
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
        // Return a map with success false or empty data to match return type
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
        headers:
            await _getHeaders(), // Ensure headers include 'Content-Type': 'application/json'
        body: json.encode(routineData), // Encode the Map to JSON string
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

  // --- CREATE MEAL
  Future<Map<String, dynamic>> createMeal(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/meals/create'),
        // 1. You must include headers for Content-Type and Auth Token
        headers: await _getHeaders(),
        // 2. You must encode the payload map into a JSON string
        body: json.encode(payload),
      );

      // 3. Handle the response status codes
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Decode the error message from the backend if available
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create meal plan');
      }
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      print("Error creating meal: $e");
      rethrow;
    }
  }

  // Edit Meal

  // Fetch all planned meals
  Future<Map<String, dynamic>> getAllMeals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meals/all'), // Adjust endpoint as per your backend
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load meals');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update an existing meal
  Future<Map<String, dynamic>> updateMeal(
    String mealId,
    Map<String, dynamic> payload,
  ) async {
    try {
      print("payload $payload");
      final response = await http.put(
        Uri.parse('$baseUrl/meals/update/$mealId'), // Adjust endpoint
        headers: await _getHeaders(),
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update meal');
      }
    } catch (e) {
      rethrow;
    }
  }

  // automatically serve meal
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

  // get Detail Vote
  Future<Map<String, dynamic>> getDetailedVotesByDate(
    String mealDate,
    String timeSlot,
  ) async {
    try {
      // Ensure the URI is constructed properly with query parameters
      final queryParams = {
        'mealDate': mealDate.toString(),
        'timeSlot': timeSlot.toLowerCase(),
      };

      final uri = Uri.parse(
        '$baseUrl/vote/get-votes',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // Return a clean empty state if no meal document exists yet
        return {"success": false, "data": [], "message": "No meal found"};
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to fetch votes');
      }
    } on SocketException {
      throw const SocketException("No Internet Connection");
    } catch (e) {
      debugPrint("Detailed Votes Error: $e");
      rethrow;
    }
  }

  // Serve meal
  Future<Map<String, dynamic>> updateServeStatus(
    String? voteId,
    String studentId,
    String mealDate,
    String timeSlot,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vote/serve'), // Update to your actual endpoint route
      headers: await _getHeaders(),
      body: jsonEncode({
        "voteId": voteId, // Will be null if they didn't vote
        "studentId": studentId,
        "mealDate": mealDate, // Format: "DD/MM/YYYY"
        "timeSlot": timeSlot, // "morning" or "night"
      }),
    );

    return jsonDecode(response.body);
  }

  // ------------------- gguest meal page apis
  // get guest meal
  Future<List<dynamic>> getHostelGuestRequests() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/guest-meals/all"),
        headers: await _getHeaders(),
      );

      final decodedData = json.decode(response.body);

      if (response.statusCode == 200) {
        return decodedData['data'] ?? [];
      } else {
        throw Exception(
          decodedData["message"] ?? "Failed to fetch guest requests",
        );
      }
    } catch (e) {
      debugPrint("Fetch Guest Requests Error: $e");
      //  Always return an empty list on error to prevent UI crashes
      return [];
    }
  }

  Future<bool> updateGuestMealStatus(String requestId, String status) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/guest-meals/status/$requestId"),
        headers: await _getHeaders(),
        body: json.encode({"status": status}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        debugPrint("Update Error: ${errorData['message']}");
        return false;
      }
    } catch (e) {
      debugPrint("Update Guest Status Exception: $e");
      return false;
    }
  }

  /// fine management

  // 1. Update the fetch method to accept the month string
  Future<List<dynamic>> getBillsByMonth(String month) async {
    try {
      // Passes the month parameter e.g., ?month=2026-03
      final response = await http.get(
        Uri.parse("$baseUrl/fines/pending?month=$month"),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching bills: $e");
      return [];
    }
  }

  // 2. Add a new method to approve/reject the bill
  Future<bool> updateBillStatus(String billId, String status) async {
    try {
      final response = await http.put(
        Uri.parse(
          "$baseUrl/fines/$billId/status",
        ), // Make sure you create this backend route
        headers: await _getHeaders(),
        body: json.encode({"status": status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating status: $e");
      return false;
    }
  }

  // 4. Save/Update the persistent Price Plan in the Database
  Future<bool> saveSettingData(Map<String, dynamic> fullConfig) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/managers/sattingData"),
        headers: await _getHeaders(),
        body: json.encode({
          "finePrices": fullConfig['finePrices'],
          "plans": fullConfig['plans'], // This is your nested Map
          "upi": fullConfig['upi'],
        }),
      );
      print("saveMealPriceTable $fullConfig \nresponse $response");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. Load the saved Price Plan when the page opens
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

  // Inside your ApiService class

  // 1. Fetch all students belonging to the manager's hostel
  Future<List<dynamic>?> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/auth/all-students",
        ), // Ensure this route exists on backend
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

  // 2. Create a fine/fee for a single specific student
  Future<bool> createIndividualFine(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(
          "$baseUrl/fines/create",
        ), // Matches your backend router.post("/create")
        headers: await _getHeaders(),
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("createIndividualFine Error: $e");
      return false;
    }
  }

  // get student sumary
  Future<Map<String, dynamic>> getStudentSummary(String studentOd) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/managers/Status/$studentOd'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      rethrow;
    }
  }
}
