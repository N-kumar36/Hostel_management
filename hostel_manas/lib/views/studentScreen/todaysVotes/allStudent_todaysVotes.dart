import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class AllStudentVotes extends StatefulWidget {
  const AllStudentVotes({super.key});

  @override
  State<AllStudentVotes> createState() => _AllStudentVotesState();
}

class _AllStudentVotesState extends State<AllStudentVotes> {
  DateTime selectedDate = DateTime.now();
  String selectedTime = "Morning";
  final api = ApiService();
  bool isLoading = false;

  List<dynamic> studentVotes = [];
  int totalGuestPlates = 0;
  int totalStudentVotes = 0;

  String baseRoutineMenu = "veg";
  int regularChoiceCount = 0;
  int halalChoiceCount = 0;
  int eggChoiceCount = 0;
  int vegChoiceCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchVotes();
  }

  Future<void> _fetchVotes() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);

    try {
      final response = await api.getDetailedVotesByDate(
        formattedDate,
        selectedTime,
      );
      if (mounted) {
        setState(() {
          final List<dynamic> allFetchedData = response['data'] ?? [];

          if (allFetchedData.isNotEmpty &&
              allFetchedData[0]['menuItem'] != null) {
            baseRoutineMenu = allFetchedData[0]['menuItem']
                .toString()
                .toLowerCase();
          } else {
            baseRoutineMenu = "veg";
          }

          studentVotes = allFetchedData.where((item) {
            final bool isGuest = item['isGuest'] == true;
            final String choice = item['choice']?.toString() ?? "";
            return isGuest || choice.isNotEmpty;
          }).toList();

          totalGuestPlates = studentVotes
              .where((item) => item['isGuest'] == true)
              .length;
          totalStudentVotes = studentVotes
              .where((item) => item['isGuest'] == false)
              .length;

          regularChoiceCount = 0;
          halalChoiceCount = 0;
          eggChoiceCount = 0;
          vegChoiceCount = 0;

          for (var item in studentVotes) {
            if (item['isGuest'] == true) continue;

            String choice = item['choice']?.toString().toLowerCase() ?? "";

            if (choice == 'regular') {
              regularChoiceCount++;
            } else if (choice == 'halal_chicken') {
              halalChoiceCount++;
            } else if (choice == 'egg_substitute') {
              eggChoiceCount++;
            } else if (choice == 'veg_forced' || choice == 'veg') {
              vegChoiceCount++;
            }
          }

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar(
          "Error: ${e.toString()}",
          Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  IconData _getChoiceIcon(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken")) return Icons.kebab_dining_rounded;
    if (c.contains("egg")) return Icons.egg_rounded;
    if (c.contains("fish")) return Icons.set_meal_rounded;
    if (c.contains("mutton")) return Icons.dinner_dining_rounded;
    if (c.contains("paneer")) return Icons.bakery_dining_rounded;
    if (c.contains("veg")) return Icons.grass_rounded;
    return Icons.restaurant_rounded;
  }

  Color _getChoiceColor(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken") || c.contains("mutton"))
      return Colors.red.shade600;
    if (c.contains("egg")) return Colors.amber.shade800;
    if (c.contains("fish")) return Colors.blue.shade600;
    if (c.contains("veg") || c.contains("paneer")) return Colors.green.shade600;
    return Colors.blueGrey.shade600;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Student Vote Registry",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildSelectors(),
          if (!isLoading) ...[
            _buildVoteSummary(),
            _buildSideBySideChoicesRow(),
          ],
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchVotes,
                    color: theme.colorScheme.primary,
                    child: _buildVoteList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    final Color menuAccentColor = _getChoiceColor(baseRoutineMenu);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
                _fetchVotes();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'Morning',
                  label: Text('Morning'),
                  icon: Icon(Icons.wb_sunny_rounded, size: 18),
                ),
                ButtonSegment<String>(
                  value: 'Night',
                  label: Text('Night'),
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
              ],
              selected: {selectedTime},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => selectedTime = newSelection.first);
                _fetchVotes();
              },
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.comfortable,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (!isLoading) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: menuAccentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: menuAccentColor.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getChoiceIcon(baseRoutineMenu),
                    color: menuAccentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "TODAY'S MAIN MENU: ",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    baseRoutineMenu.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: menuAccentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              "Voted Students",
              "$totalStudentVotes",
              Colors.indigo,
            ),
          ),
          Expanded(
            child: _buildSummaryCard(
              "Guests",
              "+$totalGuestPlates",
              Colors.orange.shade800,
            ),
          ),
          Expanded(
            child: _buildSummaryCard(
              "Total Plates",
              "${totalStudentVotes + totalGuestPlates}",
              Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySideChoicesRow() {
    final String currentMenu = baseRoutineMenu.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMiniBadge("Regular", regularChoiceCount, Colors.indigo),
            if (currentMenu == "chicken")
              _buildMiniBadge("Halal", halalChoiceCount, Colors.red.shade600),
            if (["chicken", "fish", "mutton", "paneer"].contains(currentMenu))
              _buildMiniBadge("Egg Sub", eggChoiceCount, Colors.amber.shade800),
            _buildMiniBadge("Veg Alt", vegChoiceCount, Colors.green.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, int count, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteList() {
    if (studentVotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_clear_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              "No active voting records found.",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: studentVotes.length,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemBuilder: (context, index) {
        final item = studentVotes[index];
        final bool isGuest = item['isGuest'] == true;
        final String choiceStr = item['choice']?.toString() ?? "";

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isGuest
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: Badge(
              alignment: Alignment.bottomRight,
              backgroundColor: isGuest ? Colors.orange : Colors.indigo,
              label: Icon(
                isGuest ? Icons.group_rounded : Icons.school_rounded,
                color: Colors.white,
                size: 10,
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: isGuest
                    ? Colors.orange.shade50
                    : Colors.grey.shade100,
                backgroundImage:
                    (!isGuest &&
                        item['studentPhoto'] != null &&
                        item['studentPhoto'] != "")
                    ? NetworkImage(item['studentPhoto'])
                    : null,
                child:
                    (!isGuest &&
                        (item['studentPhoto'] == null ||
                            item['studentPhoto'] == ""))
                    ? Icon(
                        Icons.person_outline_rounded,
                        color: Colors.grey.shade600,
                      )
                    : null,
              ),
            ),
            title: Text(
              item['studentName'] ?? "Unknown User",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isGuest ? Colors.orange.shade900 : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? "Approved Guest Request Plate"
                      : (item['studentEmail'] ?? "No email provided"),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getChoiceColor(choiceStr).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getChoiceIcon(choiceStr),
                        color: _getChoiceColor(choiceStr),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        choiceStr.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getChoiceColor(choiceStr),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
