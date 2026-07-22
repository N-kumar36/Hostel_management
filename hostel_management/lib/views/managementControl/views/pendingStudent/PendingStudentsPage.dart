import 'dart:io';
import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';

class PendingStudentsPage extends StatefulWidget {
  const PendingStudentsPage({super.key});

  @override
  State<PendingStudentsPage> createState() => _PendingStudentsPageState();
}

class _PendingStudentsPageState extends State<PendingStudentsPage> {
  final api = ApiService();

  //  LOCAL STATE DATA ENGINE: Safely manages array values across mutations without relying on FutureBuilder caching locks
  List<dynamic>? _localPendingList;
  bool _isInitiallyLoading = true;
  String? _executionError;

  @override
  void initState() {
    super.initState();
    _fetchPendingRegistryData();
  }

  /// Queries updates from the API service layer and safely populates localized state arrays
  Future<void> _fetchPendingRegistryData() async {
    try {
      if (mounted && _localPendingList == null) {
        setState(() {
          _isInitiallyLoading = true;
          _executionError = null;
        });
      }

      final List<dynamic> responseList = await api.getPendingStudent();

      if (mounted) {
        setState(() {
          _localPendingList = List<dynamic>.from(responseList);
          _isInitiallyLoading = false;
          _executionError = null;
        });
      }
    } catch (e) {
      debugPrint("Exception caught while parsing pending datasets: $e");
      if (mounted) {
        setState(() {
          _executionError = e.toString();
          _isInitiallyLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchPendingRegistryData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Pending Approvals",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
        ),
      ),
      body: _isInitiallyLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 2.5,
              ),
            )
          : _executionError != null
          ? _buildErrorState(
              _executionError!.contains('SocketException') ||
                  _executionError!.contains('Internet'),
              _executionError!,
            )
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.green,
              child: (_localPendingList == null || _localPendingList!.isEmpty)
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _localPendingList!.length,
                      itemBuilder: (context, index) {
                        return _buildStudentCard(_localPendingList![index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 70,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                "No pending students exist",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Pull down to check for updates",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
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
    final String roomNum = student['roomNumber'] ?? "Unassigned";
    final String currentStatus = (student['status'] ?? 'Pending').toString();

    return Container(
      key: ValueKey(studentId),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.green.withOpacity(0.08),
                  backgroundImage: photo.isNotEmpty
                      ? NetworkImage(photo)
                      : null,
                  child: photo.isEmpty
                      ? Text(
                          (student['name'] ?? "U")[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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
                        student['name'] ?? "Unknown Student",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student['email'] ?? "",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(currentStatus),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
            ),
            _infoRow(
              Icons.phone_android_rounded,
              student['phone'] ?? "No Phone Number",
            ),
            _infoRow(
              Icons.school_outlined,
              "Dept: ${student['department'] ?? 'N/A'} (${student['year'] ?? 'N/A'})",
            ),
            _infoRow(
              Icons.badge_outlined,
              "Reg No: ${student['regNum'] ?? 'N/A'}",
            ),
            _infoRow(
              Icons.meeting_room_outlined,
              "Room Assignment: Room $roomNum",
            ),
            const SizedBox(height: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 52,
              color: isOffline ? Colors.orange : Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              isOffline
                  ? "Network connection drop encountered"
                  : "Something went wrong",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              //  FIX: Pointing to the correct execution data fetch method now
              onPressed: _fetchPendingRegistryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Try Again",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final bool isUnverified = status.toLowerCase() == 'unverified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isUnverified ? Colors.blue : Colors.orange).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          color: isUnverified ? Colors.blue.shade700 : Colors.orange.shade800,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rejectButton(String id) {
    return OutlinedButton.icon(
      onPressed: () async {
        bool? confirm = await _showConfirmDialog(
          "Reject Student Application?",
          "This profile entry registry record will be deleted.",
        );
        if (confirm == true) {
          try {
            final result = await api.rejectStudent(id);
            _showSnackBar(
              result['message'] ?? "Application rejected successfully",
              Colors.red,
            );
            if (mounted) {
              setState(() {
                _localPendingList?.removeWhere(
                  (element) => element['_id'] == id,
                );
              });
            }
          } catch (e) {
            _showSnackBar("Error: $e", Colors.black87);
          }
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade100),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.close_rounded, size: 16),
      label: const Text(
        "Reject",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _approveButton(String id) {
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          await api.approveStudent(id);
          _showSnackBar("Student Access Approved Successfully!", Colors.green);
          if (mounted) {
            setState(() {
              _localPendingList?.removeWhere((element) => element['_id'] == id);
            });
          }
        } catch (e) {
          _showSnackBar("Error processing approval: $e", Colors.red);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.check_rounded, size: 16),
      label: const Text(
        "Approve",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          content,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
