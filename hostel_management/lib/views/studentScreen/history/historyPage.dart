import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final api = ApiService();
  bool isLoading = true;
  List<dynamic> history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final res = await api.getVoteHistory();

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() => history = res['history'] ?? []);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Meal History",
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
          : history.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(history[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "No history found",
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    bool hasVoted = item['voted'] ?? false;
    bool isCancelled = item['isCancelled'] ?? false;
    bool isServed = item['isServed'] ?? false; // ✅ New field

    // ✅ Parse and format the votedAt time
    String formattedVoteTime = "";
    if (item['votedAt'] != null) {
      DateTime voteDate = DateTime.parse(item['votedAt']).toLocal();
      formattedVoteTime = DateFormat('hh:mm a').format(voteDate);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Color Indicator
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: isCancelled
                    ? Colors.red
                    : (isServed
                          ? Colors.blue
                          : (hasVoted ? Colors.green : Colors.orange)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['date'] ?? "",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        _buildStatusBadge(hasVoted, isCancelled, isServed),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          item['timeSlot'] == 'morning'
                              ? Icons.wb_sunny
                              : Icons.nightlight_round,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${item['timeSlot'].toString().toUpperCase()} - ${item['menuItem'].toString().toUpperCase()}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // ✅ Show Vote Time if available
                    if (hasVoted && formattedVoteTime.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Voted at $formattedVoteTime",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool hasVoted, bool isCancelled, bool isServed) {
    String text;
    Color color;

    if (isCancelled) {
      text = "CANCELLED";
      color = Colors.red;
    } else if (isServed) {
      text = "SERVED"; // ✅ Blue badge for collected meals
      color = Colors.blue;
    } else if (hasVoted) {
      text = "VOTED";
      color = Colors.green;
    } else {
      text = "MISSED";
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isServed)
            const Icon(Icons.done_all, size: 12, color: Colors.blue),
          if (isServed) const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
