import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

/// ============================================================
/// ROUTINE SCREEN
/// ============================================================

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  void _openDedicatedMessMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DedicatedMessMenuModal(),
    );
  }

  void _openWeeklyRoutine(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WeeklyRoutineModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final surface = colorScheme.surface;
    final textPrimary = colorScheme.onSurface;
    final textSecondary = colorScheme.onSurfaceVariant;
    final primary = colorScheme.primary;
    final divider = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: textPrimary,
        title: const Text(
          "Mess Routine",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ======================================================
            // HEADER
            // ======================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5146E5), Color(0xFF3B32A0)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: const Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 30,
                  ),

                  SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mess Routine",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          "Check your weekly mess schedule",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ======================================================
            // MESS MENU TITLE
            // ======================================================
            Text(
              "Mess Menu",
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "View the dedicated weekly mess menu",
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 14),

            // ======================================================
            // DEDICATED MESS MENU
            // ======================================================
            Material(
              color: surface,
              borderRadius: BorderRadius.circular(20),

              child: InkWell(
                onTap: () => _openDedicatedMessMenu(context),
                borderRadius: BorderRadius.circular(20),

                splashColor: primary.withOpacity(0.08),
                highlightColor: primary.withOpacity(0.04),

                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: divider),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,

                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),

                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          color: primary,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              "Dedicated Mess Menu",
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              "View weekly breakfast and dinner menu",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 34,
                        height: 34,

                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(11),
                        ),

                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: primary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ======================================================
            // WEEKLY ROUTINE
            // ======================================================
            Material(
              color: surface,
              borderRadius: BorderRadius.circular(20),

              child: InkWell(
                onTap: () => _openWeeklyRoutine(context),
                borderRadius: BorderRadius.circular(20),

                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: divider),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,

                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),

                        child: const Icon(
                          Icons.calendar_view_week_rounded,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              "Weekly Mess Routine",
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              "View the current weekly routine",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 34,
                        height: 34,

                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(11),
                        ),

                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// DEDICATED MESS MENU MODAL
/// ============================================================

class DedicatedMessMenuModal extends StatelessWidget {
  const DedicatedMessMenuModal({super.key});

  // ============================================================
  // HARD-CODED MENU FROM EXCEL
  // ============================================================

  static const List<Map<String, dynamic>> menu = [
    {
      "day": "Sunday",
      "dayMenu": ["Chicken", "Rice", "Dal", "Aloo Chokha", "Achar", "Papad"],
      "nightMenu": ["Rice", "Dal", "Aloo + palak /Chana", "Achar", "Papad"],
    },
    {
      "day": "Monday",
      "dayMenu": [
        "Rice",
        "Dal",
        "Papad",
        "Aloo + Gajar + matar/chana + Soyabin",
        "papad",
      ],
      "nightMenu": ["Rice", "Dal", "Egg Curry", "Aloo Posto", "Achar", "Papad"],
    },
    {
      "day": "Tuesday",
      "dayMenu": ["Rice", "chola", "Bhujiya (Sabji)", "Achar"],
      "nightMenu": ["Rice", "Fish Curry", "Dal", "Papad", "aloo Chokha"],
    },
    {
      "day": "Wednesday",
      "dayMenu": ["Rice", "Dal", "Kabli Chana + Soyabin + Aloo", "Papad"],
      "nightMenu": ["Rice", "Chicken + Aloo", "Dal", "Papad", "Chatny"],
    },
    {
      "day": "Thursday",
      "dayMenu": ["Rice", "Dal", "Aloo + Karela Bhujiya", "Papad", "Achar"],
      "nightMenu": ["Rice", "Egg", "Dal", "Aloo Posto", "Papad"],
    },
    {
      "day": "Friday",
      "dayMenu": ["Rice", "Mixed Veg", "Dal", "Papad", "Achar"],
      "nightMenu": ["Rice", "Fish", "Dal", "Papad", "Benguni"],
    },
    {
      "day": "Saturday",
      "dayMenu": ["Veg Fried Rice", "Hara Sabji + Soyabin", "Raita"],
      "nightMenu": ["Mix Veg Khichri", "Papad", "Achar"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final surface = colorScheme.surface;
    final textPrimary = colorScheme.onSurface;
    final textSecondary = colorScheme.onSurfaceVariant;
    final primary = colorScheme.primary;
    final divider = theme.dividerColor;

    final isDark = theme.brightness == Brightness.dark;

    final handleColor = isDark
        ? const Color(0xFF4A4F59)
        : const Color(0xFFD1D5DB);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),

      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),

      child: Column(
        children: [
          // ======================================================
          // HEADER
          // ======================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),

            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,

                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,

                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),

                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: primary,
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dedicated Mess Menu",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            "Weekly breakfast & dinner menu",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: divider),

          // ======================================================
          // MENU LIST
          // ======================================================
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),

              physics: const BouncingScrollPhysics(),

              itemCount: menu.length,

              itemBuilder: (context, index) {
                final item = menu[index];

                return _buildDayCard(
                  context: context,
                  day: item["day"] as String,
                  dayMenu: List<String>.from(item["dayMenu"]),
                  nightMenu: List<String>.from(item["nightMenu"]),
                  primary: primary,
                  surface: surface,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  divider: divider,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAY CARD
  // ============================================================

  Widget _buildDayCard({
    required BuildContext context,
    required String day,
    required List<String> dayMenu,
    required List<String> nightMenu,
    required Color primary,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: divider),
      ),

      child: Column(
        children: [
          // ======================================================
          // DAY HEADER
          // ======================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),

            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),

            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,

                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: primary,
                    size: 17,
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  day,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // DAY / NIGHT MENU
          // ======================================================
          Padding(
            padding: const EdgeInsets.all(14),

            child: Column(
              children: [
                _buildMealBlock(
                  icon: Icons.wb_sunny_rounded,
                  title: "Day",
                  items: dayMenu,
                  accent: const Color(0xFFF59E0B),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),

                const SizedBox(height: 14),

                Container(height: 1, color: divider),

                const SizedBox(height: 14),

                _buildMealBlock(
                  icon: Icons.nightlight_round,
                  title: "Night",
                  items: nightMenu,
                  accent: const Color(0xFF6366F1),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MEAL BLOCK
  // ============================================================

  Widget _buildMealBlock({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,

              decoration: BoxDecoration(
                color: accent.withOpacity(0.11),
                borderRadius: BorderRadius.circular(9),
              ),

              child: Icon(icon, color: accent, size: 17),
            ),

            const SizedBox(width: 9),

            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        Wrap(
          spacing: 7,
          runSpacing: 7,

          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

              decoration: BoxDecoration(
                color: accent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.12)),
              ),

              child: Text(
                item,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// ============================================================
/// WEEKLY ROUTINE MODAL
/// ============================================================

class WeeklyRoutineModal extends StatefulWidget {
  const WeeklyRoutineModal({super.key});

  @override
  State<WeeklyRoutineModal> createState() => _WeeklyRoutineModalState();
}

class _WeeklyRoutineModalState extends State<WeeklyRoutineModal> {
  final api = ApiService();

  Map<String, dynamic>? routineData;
  bool isLoading = true;

  final Map<String, String> dayNames = {
    "1": "Monday",
    "2": "Tuesday",
    "3": "Wednesday",
    "4": "Thursday",
    "5": "Friday",
    "6": "Saturday",
    "7": "Sunday",
  };

  @override
  void initState() {
    super.initState();
    _getRoutine();
  }

  Future<void> _getRoutine() async {
    try {
      final res = await api.getroutine();

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          routineData = res['weeklyRoutine']['routine'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint("Routine Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final surface = colorScheme.surface;
    final textPrimary = colorScheme.onSurface;
    final textSecondary = colorScheme.onSurfaceVariant;
    final primary = colorScheme.primary;
    final divider = theme.dividerColor;

    final isDark = theme.brightness == Brightness.dark;

    final handleColor = isDark
        ? const Color(0xFF4A4F59)
        : const Color(0xFFD1D5DB);

    return Container(
      padding: const EdgeInsets.all(20),

      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),

      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),

            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Text(
            "Weekly Mess Routine",
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          if (isLoading)
            Center(child: CircularProgressIndicator(color: primary))
          else if (routineData == null)
            Center(
              child: Text(
                "Failed to load routine",
                style: TextStyle(color: textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: 7,

                separatorBuilder: (context, index) {
                  return Divider(color: divider, height: 1);
                },

                itemBuilder: (context, index) {
                  final String dayKey = (index + 1).toString();

                  final dayRoutine = routineData![dayKey];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),

                    child: Row(
                      children: [
                        SizedBox(
                          width: 85,

                          child: Text(
                            dayNames[dayKey]!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "☀️ ${dayRoutine['morning'].toString().toUpperCase()}",
                            style: TextStyle(fontSize: 13, color: textPrimary),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "🌙 ${dayRoutine['night'].toString().toUpperCase()}",
                            style: TextStyle(fontSize: 13, color: textPrimary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
