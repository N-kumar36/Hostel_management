import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:intl/intl.dart';

class DailyMenuCard extends StatefulWidget {
  const DailyMenuCard({super.key});

  @override
  DailyMenuCardState createState() => DailyMenuCardState();
}

class DailyMenuCardState extends State<DailyMenuCard> {
  final api = ApiService();
  Map<String, dynamic>? todayMeal;
  Map<String, dynamic>? voteStatus;
  bool isLoading = true;
  bool isActionLoading = false;

  @override
  void initState() {
    super.initState();
    fetchTodayData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchTodayData();
  }

  Future<void> fetchTodayData() async {
    if (todayMeal == null) setState(() => isLoading = true);

    try {
      final Map<String, dynamic> weeklyData = await api.fetchWeeklyMeals();
      String todayKey = DateFormat('dd/MM/yyyy').format(DateTime.now());

      if (weeklyData.containsKey(todayKey)) {
        todayMeal = weeklyData[todayKey];

        final statusRes = await api.checkVoteStatus(todayMeal!['_id']);
        if (statusRes['success'] == true) {
          setState(() {
            voteStatus = statusRes['status'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching today's menu: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  DateTime _parseLockTime(String dateStr, String lockTimeIso) {
    try {
      final mealDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      final lockDT = DateTime.parse(lockTimeIso);
      return DateTime(
        mealDate.year,
        mealDate.month,
        mealDate.day,
        lockDT.hour,
        lockDT.minute,
      );
    } catch (e) {
      return DateTime.now().subtract(const Duration(minutes: 1));
    }
  }

  Future<void> _handleVoteAction(
    String slot,
    bool currentlyVoted,
    bool isLocked,
    bool isCancelled,
  ) async {
    if (isLocked || isCancelled || isActionLoading) return;

    setState(() => isActionLoading = true);
    try {
      Map<String, dynamic> res;
      if (currentlyVoted) {
        res = await api.cancelVote(todayMeal!['_id'], slot);
      } else {
        // ✨ FIX: Pass 'regular' or the base menu value properly as expected by backend
        final String baseMenu = (todayMeal![slot]['manu'] ?? 'regular').toString();
        
        res = await api.postVote({
          "mealId": todayMeal!['_id'].toString(),
          "timeSlot": slot,
          "mealType": "regular", // Quick vote defaults to regular preference
        });
      }

      if (res['success'] == true) {
        _showSnackBar(res['message'] ?? "Action Successful", Colors.green);
        await fetchTodayData();
      } else {
        _showSnackBar(res['message'] ?? "Action failed", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isActionLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (todayMeal == null) {
      return const Center(child: Text("No menu set for today."));
    }

    final morningStates = _getMealStates(todayMeal!['morning'], "morning");
    final nightStates = _getMealStates(todayMeal!['night'], "night");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _menuRow(
            "Morning",
            todayMeal!['morning']['manu'] ?? 'Veg',
            morningStates,
            Colors.orange,
          ),
          const Divider(height: 24),
          _menuRow(
            "Night",
            todayMeal!['night']['manu'] ?? 'Veg',
            nightStates,
            Colors.indigo,
          ),
        ],
      ),
    );
  }

  ({
    bool isLocked,
    bool isCancelled,
    bool isServed,
    bool voted,
    String formattedTime,
  })
  _getMealStates(Map<String, dynamic> meal, String slot) {
    final lockTime = _parseLockTime(
      DateFormat('dd/MM/yyyy').format(DateTime.now()),
      meal['lockTime'] ?? "",
    );

    final bool voted = voteStatus?[slot] == true;
    final bool isServed = voteStatus?['${slot}Served'] == true;

    final isLocked =
        (meal['isLocked'] == true) ||
        DateTime.now().isAfter(lockTime) ||
        isServed;
    final isCancelled = meal['isCancelled'] == true;
    final formattedTime = DateFormat('hh:mm a').format(lockTime);

    return (
      isLocked: isLocked,
      isCancelled: isCancelled,
      isServed: isServed,
      voted: voted,
      formattedTime: formattedTime,
    );
  }

  Widget _menuRow(String label, String dish, var s, Color color) {
    Color btnColor = s.voted ? Colors.green : Colors.deepPurple;
    if (s.isCancelled) btnColor = Colors.red.shade300;
    if (s.isServed) btnColor = Colors.teal;
    if (s.isLocked && !s.voted && !s.isServed) btnColor = Colors.grey;

    String buttonText = s.voted ? "CANCEL" : "VOTE";
    if (s.isServed) buttonText = "SERVED";

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            label == "Morning" ? Icons.wb_sunny : Icons.nightlight_round,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.isCancelled ? "CANCELLED" : dish.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: s.isCancelled ? Colors.red : Colors.black,
                    ),
                  ),
                  if (s.isServed) ...[
                    const SizedBox(width: 8),
                    _statusBadge("SERVED", Colors.green),
                  ],
                ],
              ),
              Text(
                s.isServed
                    ? "Meal consumed"
                    : (s.isLocked
                        ? "Voting Closed"
                        : "Ends at ${s.formattedTime}"),
                style: TextStyle(
                  fontSize: 11,
                  color: (s.isLocked || s.isServed)
                      ? Colors.blueGrey
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed:
              (s.isLocked || s.isCancelled || s.isServed || isActionLoading)
                  ? null
                  : () => _handleVoteAction(
                        label.toLowerCase(),
                        s.voted,
                        s.isLocked,
                        s.isCancelled,
                      ),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: btnColor.withOpacity(0.6),
            elevation: 0,
            minimumSize: const Size(80, 35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: isActionLoading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}