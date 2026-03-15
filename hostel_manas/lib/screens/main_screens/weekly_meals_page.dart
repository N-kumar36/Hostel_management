import 'package:HostelMess/screens/main_screens/utility/vote_page.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyMealsPage extends StatefulWidget {
  const WeeklyMealsPage({super.key});

  @override
  State<WeeklyMealsPage> createState() => _WeeklyMealsPageState();
}

class _WeeklyMealsPageState extends State<WeeklyMealsPage> {
  final api = ApiService();
  late Future<Map<String, dynamic>> _mealsFuture;
  List<dynamic> _userVoteStatus = [];

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  // Load meals and then fetch the voting status for those specific meals
  Future<void> _loadMeals() async {
    setState(() {
      _mealsFuture = api.fetchWeeklyMeals();
    });

    try {
      final meals = await _mealsFuture;
      // Extract all meal IDs from the map to check status in one batch
      final ids = meals.values.map((m) => m['_id'].toString()).toList();

      // Fetch user-specific vote status (voted, served, etc.)
      final status = await api.checkUserVotes(ids);

      if (mounted) {
        setState(() {
          _userVoteStatus = status;
        });
      }
    } catch (e) {
      debugPrint("Error loading meal status: $e");
    }
  }

  // Helper to find if a vote exists for a specific meal and slot
  Map<String, dynamic>? _getVoteInfo(String mealId, String slot) {
    try {
      return _userVoteStatus.firstWhere(
        (v) => v['mealId'] == mealId && v['timeSlot'] == slot.toLowerCase(),
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weekly Votes"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _mealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return _buildErrorState();
          }

          final weekly = snapshot.data!;
          final List<String> dates = weekly.keys.toList();

          // Sort dates chronologically
          dates.sort((a, b) {
            try {
              return DateFormat(
                "dd/MM/yyyy",
              ).parse(a).compareTo(DateFormat("dd/MM/yyyy").parse(b));
            } catch (e) {
              return 0;
            }
          });

          return RefreshIndicator(
            onRefresh: _loadMeals,
            child: ListView.builder(
              itemCount: dates.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, i) {
                final String dateString = dates[i];
                final mealData = weekly[dateString];
                final mealId = mealData['_id'].toString();

                // Get vote info for morning and night
                final morningVote = _getVoteInfo(mealId, "Morning");
                final nightVote = _getVoteInfo(mealId, "Night");

                return _buildMealCard(
                  dateString,
                  mealData,
                  morningVote,
                  nightVote,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealCard(
    String date,
    dynamic mealData,
    dynamic morningVote,
    dynamic nightVote,
  ) {
    String dayName = "Unknown";
    try {
      DateTime parsedDate = DateFormat("dd/MM/yyyy").parse(date);
      dayName = DateFormat('EEEE').format(parsedDate);
    } catch (_) {}

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.deepPurple,
                  ),
                ),
                Text(date, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildMealRow(
                        Icons.sunny,
                        "Morning",
                        mealData['morning'],
                        morningVote,
                      ),
                      const SizedBox(height: 12),
                      _buildMealRow(
                        Icons.nightlight_round,
                        "Night",
                        mealData['night'],
                        nightVote,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VotePage(
                          id: mealData['_id'].toString(),
                          date: date,
                          morning: Map<String, dynamic>.from(
                            mealData['morning'],
                          ),
                          night: Map<String, dynamic>.from(mealData['night']),
                        ),
                      ),
                    ).then(
                      (_) => _loadMeals(),
                    ); // Reload status when returning from voting
                  },
                  child: const Text("Vote"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealRow(
    IconData icon,
    String label,
    dynamic mealSlotData,
    Map<String, dynamic>? voteInfo,
  ) {
    bool isCancelled = mealSlotData['isCancelled'] ?? false;
    bool isVoted = voteInfo != null;
    bool isServed = voteInfo?['isServed'] ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.orange),
        const SizedBox(width: 8),

        // Wrap text + badge together
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$label: ${mealSlotData['manu'] ?? 'Not set'}",
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(width: 4),

            if (isCancelled)
              _statusBadge("CANCELLED", Colors.red)
            else if (isServed)
              _statusBadge("SERVED", Colors.green)
            else if (isVoted)
              _statusBadge("VOTED", Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No meals found for this week."),
          TextButton(onPressed: _loadMeals, child: const Text("Refresh")),
        ],
      ),
    );
  }
}
