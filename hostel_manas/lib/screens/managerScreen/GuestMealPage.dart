import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class GuestMealPage extends StatefulWidget {
  const GuestMealPage({super.key});

  @override
  State<GuestMealPage> createState() => _GuestMealPageState();
}

class _GuestMealPageState extends State<GuestMealPage> {
  final api = ApiService();
  List<dynamic> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final response = await api.getHostelGuestRequests();
      if (mounted) {
        setState(() {
          // Extracts the raw data array block safely out of backend container response wrapper
          requests = response['data'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        debugPrint("Error loading guest requests: $e");
      }
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> request,
    String status,
  ) async {
    try {
      final payload = {
        "mealId": request['mealId'],
        "timeSlot": request['mealTime'] ?? "morning",
        "requestId": request['_id'],
        "status": status,
      };

      final res = await api.updateGuestMealStatus(payload);

      if (res['success'] == true && mounted) {
        setState(() {
          // Find the precise entry match index locally
          final targetIdx = requests.indexWhere(
            (element) => element['_id'] == request['_id'],
          );
          if (targetIdx != -1) {
            // Apply the updated payload safely returned from our updated controller block
            if (res['data'] != null) {
              requests[targetIdx] = res['data'];
            } else {
              requests[targetIdx]['status'] = status;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Request marked as ${status.toUpperCase()} successfully!",
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showSnackBar(
          res['message'] ?? "Action rejected by server",
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("Status update error: $e");
      _showSnackBar("Failed to update status: $e", Colors.red);
    }
  }

  IconData _getVariationIcon(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken")) return Icons.kebab_dining_rounded;
    if (c.contains("egg")) return Icons.egg_rounded;
    if (c.contains("fish")) return Icons.set_meal_rounded;
    if (c.contains("veg")) return Icons.grass_rounded;
    return Icons.restaurant_rounded;
  }

  Color _getVariationColor(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken")) return Colors.red.shade700;
    if (c.contains("egg")) return Colors.amber.shade800;
    if (c.contains("fish")) return Colors.blue.shade700;
    if (c.contains("veg")) return Colors.green.shade700;
    return Colors.grey.shade700;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Guest Meal Requests",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              color: Colors.deepPurple,
              child: requests.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(requests[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String statusStr =
        request['status']?.toString().toLowerCase() ?? 'pending';
    bool isPending = statusStr == 'pending';

    // ✅ FIXED: Safely pull populated student attributes check structure fallbacks
    String hostStudentName = "Unknown Student Host";
    String roomNumber = "N/A";

    if (request['studentId'] != null) {
      if (request['studentId'] is Map) {
        hostStudentName =
            request['studentId']['name']?.toString() ?? "Unknown Student Host";
        roomNumber = request['studentId']['roomNumber']?.toString() ?? "N/A";
      } else {
        hostStudentName = "Student Linked Reference";
      }
    }

    final String preference =
        request['guestItemPreference']?.toString() ?? "regular";
    final Color variantColor = _getVariationColor(preference);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade50,
              child: const Icon(Icons.person, color: Colors.deepPurple),
            ),
            title: Text(
              hostStudentName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  "Room Number: $roomNumber",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Total Guest Plates: ${request['guestCount']} • Slot: ${request['mealTime'].toString().toUpperCase()}",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  "Requested Date: ${request['mealDate']}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),

                // ✨ NEW: Live Variant Custom Selection Indicator Badge Line view components
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getVariationIcon(preference),
                      size: 14,
                      color: variantColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "PREFERENCE: ${preference.replaceAll('_', ' ').toUpperCase()}",
                      style: TextStyle(
                        fontSize: 11,
                        color: variantColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _statusBadge(statusStr),
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 16, right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(request, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "REJECT",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(request, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        "APPROVE",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'approved'
        ? Colors.green
        : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No pending guest requests listed.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
