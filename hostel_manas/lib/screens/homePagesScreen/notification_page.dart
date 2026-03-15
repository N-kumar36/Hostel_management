import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock notification data
    final List<Map<String, dynamic>> notifications = [
      {
        "title": "Vote for Dinner!",
        "message": "Today's dinner menu has been set. Don't forget to cast your vote before 6:30 PM.",
        "time": DateTime.now().subtract(const Duration(minutes: 30)),
        "type": "vote",
        "isRead": false,
      },
      {
        "title": "Payment Successful",
        "message": "Your mess fee of ₹2500 for March has been successfully recorded.",
        "time": DateTime.now().subtract(const Duration(hours: 2)),
        "type": "payment",
        "isRead": true,
      },
      {
        "title": "Meal Served",
        "message": "You have consumed your morning meal: Egg Curry & Rice.",
        "time": DateTime.now().subtract(const Duration(hours: 8)),
        "type": "served",
        "isRead": true,
      },
      {
        "title": "New Notice",
        "message": "Hostel cleaning schedule for the upcoming weekend has been posted.",
        "time": DateTime.now().subtract(const Duration(days: 1)),
        "type": "notice",
        "isRead": true,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {}, // Logic to mark all as read
            child: const Text("Mark all read", style: TextStyle(color: Colors.white70, fontSize: 12)),
          )
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _buildNotificationCard(item);
              },
            ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    IconData icon;
    Color color;

    // Assign icons based on type
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: item['isRead'] ? null : Border.all(color: Colors.deepPurple.shade100, width: 1.5),
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
          item['title'],
          style: TextStyle(
            fontWeight: item['isRead'] ? FontWeight.w600 : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item['message'],
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM, hh:mm a').format(item['time']),
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