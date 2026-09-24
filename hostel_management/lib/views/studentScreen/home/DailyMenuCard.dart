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

  // ===========================================================================
  // THEME HELPERS
  // ===========================================================================

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _dividerColor {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF2A2E39)
        : const Color(0xFFE5E7EB);
  }

  Color get _shadowColor {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? Colors.black.withOpacity(0.22)
        : Colors.black.withOpacity(0.05);
  }

  Color get _disabledButtonColor {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF4B505C)
        : Colors.grey;
  }

  // ===========================================================================
  // INIT
  // ===========================================================================

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

  // ===========================================================================
  // FETCH TODAY'S DATA
  // ===========================================================================

  Future<void> fetchTodayData() async {
    if (todayMeal == null && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final Map<String, dynamic> weeklyData = await api.fetchWeeklyMeals();

      final String todayKey = DateFormat('dd/MM/yyyy').format(DateTime.now());

      if (weeklyData.containsKey(todayKey)) {
        todayMeal = weeklyData[todayKey];

        final statusRes = await api.checkVoteStatus(todayMeal!['_id']);

        if (statusRes['success'] == true && mounted) {
          setState(() {
            voteStatus = statusRes['status'];
          });
        }
      } else {
        todayMeal = null;
      }
    } catch (e) {
      debugPrint("Error fetching today's menu: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // PARSE LOCK TIME
  // ===========================================================================

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

  // ===========================================================================
  // VOTE ACTION
  // ===========================================================================

  Future<void> _handleVoteAction(
    String slot,
    bool currentlyVoted,
    bool isLocked,
    bool isCancelled,
  ) async {
    if (isLocked || isCancelled || isActionLoading) {
      return;
    }

    if (mounted) {
      setState(() {
        isActionLoading = true;
      });
    }

    try {
      Map<String, dynamic> res;

      if (currentlyVoted) {
        res = await api.cancelVote(todayMeal!['_id'], slot);
      } else {
        res = await api.postVote({
          "mealId": todayMeal!['_id'].toString(),
          "timeSlot": slot,
          "mealType": "regular",
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
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (todayMeal == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _dividerColor),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 23,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "No menu set for today.",
              style: TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final morningStates = _getMealStates(todayMeal!['morning'], "morning");

    final nightStates = _getMealStates(todayMeal!['night'], "night");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dividerColor),
        boxShadow: [
          BoxShadow(
            color: _shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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

          Divider(height: 24, thickness: 1, color: _dividerColor),

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

  // ===========================================================================
  // MEAL STATES
  // ===========================================================================

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

    final bool isLocked =
        (meal['isLocked'] == true) ||
        DateTime.now().isAfter(lockTime) ||
        isServed;

    final bool isCancelled = meal['isCancelled'] == true;

    final String formattedTime = DateFormat('hh:mm a').format(lockTime);

    return (
      isLocked: isLocked,
      isCancelled: isCancelled,
      isServed: isServed,
      voted: voted,
      formattedTime: formattedTime,
    );
  }

  // ===========================================================================
  // MENU ROW
  // ===========================================================================

  Widget _menuRow(String label, String dish, dynamic s, Color color) {
    Color btnColor = s.voted ? Colors.green : Colors.deepPurple;

    if (s.isCancelled) {
      btnColor = Colors.red.shade300;
    }

    if (s.isServed) {
      btnColor = Colors.teal;
    }

    if (s.isLocked && !s.voted && !s.isServed) {
      btnColor = _disabledButtonColor;
    }

    String buttonText = s.voted ? "CANCEL" : "VOTE";

    if (s.isServed) {
      buttonText = "SERVED";
    }

    return Row(
      children: [
        // ============================================================
        // MEAL ICON
        // ============================================================
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            label == "Morning" ? Icons.wb_sunny : Icons.nightlight_round,
            color: color,
            size: 20,
          ),
        ),

        const SizedBox(width: 16),

        // ============================================================
        // MEAL INFORMATION
        // ============================================================
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      s.isCancelled ? "CANCELLED" : dish.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: s.isCancelled ? Colors.red : _textPrimary,
                      ),
                    ),
                  ),

                  if (s.isServed) ...[
                    const SizedBox(width: 8),

                    _statusBadge("SERVED", Colors.green),
                  ],
                ],
              ),

              const SizedBox(height: 3),

              Text(
                s.isServed
                    ? "Meal consumed"
                    : (s.isLocked
                          ? "Voting Closed"
                          : "Ends at ${s.formattedTime}"),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: (s.isLocked || s.isServed)
                      ? _textSecondary
                      : _textSecondary.withOpacity(0.82),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // ============================================================
        // VOTE BUTTON
        // ============================================================
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

            disabledBackgroundColor: btnColor.withOpacity(0.60),

            disabledForegroundColor: Colors.white.withOpacity(0.85),

            elevation: 0,

            minimumSize: const Size(80, 35),

            padding: const EdgeInsets.symmetric(horizontal: 10),

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

  // ===========================================================================
  // STATUS BADGE
  // ===========================================================================

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
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
