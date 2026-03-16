import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class StudentHistoryView extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String type; // 'Votes', 'Served', 'Fines', 'Guests'

  const StudentHistoryView({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.type,
  });

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'success': return Colors.green;
      case 'processing': return Colors.orange;
      case 'pending': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("$studentName's $type", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<dynamic>(
        future: type == 'Fines' ? api.getMyFines() : api.getMealStatus(studentId), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purple));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("No records found"));
          }

          List<dynamic> list = [];
          if (type == 'Fines') {
            list = snapshot.data is List ? snapshot.data : (snapshot.data['data'] ?? []);
          } else {
            final data = snapshot.data as Map<String, dynamic>;
            List<dynamic> fullHistory = data['history'] ?? [];
            
            // ✅ Only include items where student actually voted
            list = fullHistory.where((item) => item['voted'] == true).toList();
          }

          // ✅ NEW FILTER LOGIC:
          // 1. If 'Served', show only served meals.
          // 2. If 'Guests', show only guest meals.
          // 3. Otherwise (Votes), show all voted meals.
          final filteredList = type == 'Served'
              ? list.where((item) => item['isServed'] == true).toList()
              : type == 'Guests'
                  ? list.where((item) => item['isGuest'] == true).toList()
                  : list;

          if (filteredList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No $type recorded yet", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredList.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final item = filteredList[index];
              final bool isGuest = item['isGuest'] ?? false;
              final String guestName = item['guestName'] ?? "";
              final String status = item['status']?.toString() ?? 'pending';
              final String date = (item['date'] ?? "").toString();

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getIconColor(type, isGuest).withOpacity(0.1),
                    child: Icon(_getIcon(type, isGuest), color: _getIconColor(type, isGuest), size: 20),
                  ),
                  title: Text(
                    type == 'Fines' 
                        ? (item['title'] ?? "Fine") 
                        : isGuest 
                            ? "${item['menuItem'] ?? 'Meal'} (Guest)" 
                            : (item['menuItem'] ?? "Meal"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(isGuest ? "Guest: $guestName\nDate: $date" : "Date: $date"),
                  isThreeLine: isGuest,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        type == 'Fines' ? "₹${item['amount']}" : (item['timeSlot'] ?? "").toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: type == 'Fines' ? _getStatusColor(status) : Colors.blue,
                        ),
                      ),
                      if (type != 'Fines')
                        Text(
                          item['isServed'] == true ? "SERVED" : "NOT SERVED",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item['isServed'] == true ? Colors.green : Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type, bool isGuest) {
    if (type == 'Fines') return Icons.receipt_long;
    if (isGuest) return Icons.group;
    return type == 'Served' ? Icons.restaurant : Icons.how_to_vote;
  }

  Color _getIconColor(String type, bool isGuest) {
    if (type == 'Fines') return Colors.redAccent;
    if (isGuest) return Colors.purple;
    return type == 'Served' ? Colors.green : Colors.blue;
  }
}