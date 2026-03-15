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
    setState(() => isLoading = true);
    try {
      // You should have an API method: getHostelGuestRequests()
      final data = await api.getHostelGuestRequests(); 
      setState(() {
        requests = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error: $e");
    }
  }

  Future<void> _updateStatus(String requestId, String status) async {
    try {
      // API call to update status to 'approved' or 'rejected'
      final success = await api.updateGuestMealStatus(requestId, status);
      if (success) {
        _fetchRequests(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request $status"), backgroundColor: Colors.black87),
        );
      }
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Guest Meal Requests", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
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
    bool isPending = request['status'] == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade50,
              child: const Icon(Icons.person, color: Colors.deepPurple),
            ),
            title: Text(
              request['studentId']['name'] ?? "Unknown Student",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Room: ${request['studentId']['roomNumber'] ?? 'N/A'}"),
                Text("Guests: ${request['guestCount']} • ${request['mealTime']}"),
                Text("Date: ${request['mealDate']}"),
              ],
            ),
            trailing: _statusBadge(request['status']),
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, left: 16, right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(request['_id'], 'rejected'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("REJECT"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(request['_id'], 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("APPROVE"),
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
    Color color = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No pending requests", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}