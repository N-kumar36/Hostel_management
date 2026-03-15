import 'dart:io';
// Required for json.decode
// Required for the API call
import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';

class PendingStudentsPage extends StatefulWidget {
  const PendingStudentsPage({super.key});

  @override
  State<PendingStudentsPage> createState() => _PendingStudentsPageState();
}

class _PendingStudentsPageState extends State<PendingStudentsPage> {
  final api = ApiService();

  Future<void> _handleRefresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Pending Approvals",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.green,
        child: FutureBuilder<List<dynamic>>(
          future: api.getPendingStudent(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.green),
              );
            }

            if (snapshot.hasError) {
              final bool isOffline = snapshot.error is SocketException;
              return _buildErrorState(isOffline, snapshot.error.toString());
            }

            // Logic: If data is null or list is empty, show the "No Pending" UI
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(); // This shows "No pending students exist"
            }

            final List<dynamic> pendingList = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pendingList.length,
              itemBuilder: (context, index) {
                return _buildStudentCard(pendingList[index]);
              },
            );
          },
        ),
      ),
    );
  }

  // --- Updated Empty State UI ---
  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Allows pull-to-refresh even when empty
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                "No pending students exist",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Pull down to check for updates",
                style: TextStyle(fontSize: 14, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(dynamic student) {
    final String photo = student['photoURL'] ?? "";
    final String studentId = student['_id'] ?? "";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  backgroundImage: photo.isNotEmpty
                      ? NetworkImage(photo)
                      : null,
                  child: photo.isEmpty
                      ? Text(
                          (student['name'] ?? "U")[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? "Unknown",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        student['email'] ?? "",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(),
              ],
            ),
            const Divider(height: 32),
            _infoRow(
              Icons.phone_android_rounded,
              student['phone'] ?? "No Phone",
            ),
            _infoRow(
              Icons.school_outlined,
              "Dept: ${student['department'] ?? 'N/A'}",
            ),
            _infoRow(
              Icons.badge_outlined,
              "Reg No: ${student['regNum'] ?? 'N/A'}",
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _rejectButton(studentId)),
                const SizedBox(width: 12),
                Expanded(child: _approveButton(studentId)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isOffline, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
            size: 60,
            color: isOffline ? Colors.orange : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            isOffline ? "You are Offline" : "Something went wrong",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              "Try Again",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        "Pending",
        style: TextStyle(
          fontSize: 10,
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[400]),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _rejectButton(String id) {
    return TextButton(
      onPressed: () async {
        bool? confirm = await _showConfirmDialog(
          "Reject Student?",
          "Registration will be deleted.",
        );
        if (confirm == true) {
          try {
            final result = await api.rejectStudent(id);
            _showSnackBar(result['message'], Colors.red);
            setState(() {});
          } catch (e) {
            _showSnackBar("Error: $e", Colors.black);
          }
        }
      },
      style: TextButton.styleFrom(foregroundColor: Colors.red),
      child: const Text("Reject"),
    );
  }

  Widget _approveButton(String id) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await api.approveStudent(id);
          _showSnackBar("Student Approved!", Colors.green);
          setState(() {});
        } catch (e) {
          _showSnackBar("Error: $e", Colors.red);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text("Approve"),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
