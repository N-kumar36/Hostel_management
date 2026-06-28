import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart'; // Adjust path if needed

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final api = ApiService();
  bool isLoading = true;
  List<dynamic> notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => isLoading = true);
    try {
      final res = await api.getNotifications();
      if (mounted && res['success'] == true) {
        setState(() {
          notifications = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    // Optimistic UI update: instantly make them read on screen
    setState(() {
      for (var note in notifications) {
        note['isRead'] = true;
      }
    });

    // Send request to backend
    final success = await api.markAllNotificationsRead();
    if (!success && mounted) {
      // If it fails, you might want to show a snackbar or refresh
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update notifications server")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Only show "Mark all read" if there are actual unread notifications
          if (notifications.any((n) => n['isRead'] == false))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text("Mark all read", style: TextStyle(color: Colors.white70, fontSize: 12)),
            )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    IconData icon;
    Color color;

    // Assign icons based on type from Database
    switch (item['type']) {
      case 'vote':
        icon = Icons.how_to_vote;
        color = Colors.orange;
        break;
      case 'payment':
        icon = Icons.account_balance_wallet;
        color = Colors.green;
        break;
      case 'served':
        icon = Icons.restaurant;
        color = Colors.blue;
        break;
      default:
        icon = Icons.campaign;
        color = Colors.deepPurple;
    }

    final bool isRead = item['isRead'] ?? false;
    
    // Safely parse the MongoDB date string
    DateTime time;
    try {
      time = DateTime.parse(item['createdAt']).toLocal();
    } catch (e) {
      time = DateTime.now();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isRead ? null : Border.all(color: Colors.deepPurple.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          item['title'] ?? "Notification",
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item['message'] ?? "",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM, hh:mm a').format(time),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No notifications yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}