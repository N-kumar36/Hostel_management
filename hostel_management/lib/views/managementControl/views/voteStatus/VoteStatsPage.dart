import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class VoteStatusSelectionPage extends StatefulWidget {
  const VoteStatusSelectionPage({super.key});

  @override
  State<VoteStatusSelectionPage> createState() =>
      _VoteStatusSelectionPageState();
}

class _VoteStatusSelectionPageState extends State<VoteStatusSelectionPage> {
  DateTime selectedDate = DateTime.now();
  String selectedTime = "Morning";
  final api = ApiService();
  bool isLoading = false;
  bool isActionLoading = false;

  List<dynamic> studentVotes = [];
  int totalGuestPlates = 0;
  int totalStudentVotes = 0;

  // Dynamic state trackers mapped straight to Mongoose schema values
  String baseRoutineMenu = "veg";
  String mealSequenceNumber = "0";
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
          // ⚡ Enforces map checking matching your root Postman envelope structure
          final List<dynamic> allFetchedData = response['data'] ?? [];

          // 1. Extract base menu and meal number directly out of the root keys or first payload
          mealSequenceNumber = (response['mealsNum'] ?? "0").toString();

          if (allFetchedData.isNotEmpty) {
            final firstItem = allFetchedData[0];
            baseRoutineMenu = (firstItem['menuItem'] ?? "veg")
                .toString()
                .toLowerCase();
            if (mealSequenceNumber == "0") {
              mealSequenceNumber = (firstItem['mealsNum'] ?? "0").toString();
            }
          } else {
            baseRoutineMenu = "veg";
          }

          // 2. Filter out non-voted students completely so they NEVER show in this UI list
          studentVotes = allFetchedData.where((item) {
            final bool isGuest = item['isGuest'] == true;
            final String choice = item['choice']?.toString() ?? "";
            return isGuest || choice.isNotEmpty;
          }).toList();

          // 3. Calculate Summary Overviews from the filtered list
          totalGuestPlates = studentVotes
              .where((item) => item['isGuest'] == true)
              .length;
          totalStudentVotes = studentVotes
              .where((item) => item['isGuest'] == false)
              .length;

          // 4. Reset counter metrics explicitly before counting loops
          regularChoiceCount = 0;
          halalChoiceCount = 0;
          eggChoiceCount = 0;
          vegChoiceCount = 0;

          // 5. Aggregate metrics from the filtered active voters list
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
        _showSnackBar("Error: ${e.toString()}", Colors.red);
      }
    }
  }

  Future<void> _markAsServed(String uniqueId, Map<String, dynamic> item) async {
    setState(() => isActionLoading = true);

    try {
      final String? vId = item['voteId']?.toString();
      final String sId = item['studentId']?.toString() ?? "";
      String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);

      final res = await api.updateServeStatus(
        vId,
        sId,
        formattedDate,
        selectedTime,
      );

      if (mounted) {
        if (res['success'] == true) {
          final String resolvedMealType = res['mealType'] ?? "Served";

          setState(() {
            final masterIndex = studentVotes.indexWhere(
              (v) =>
                  (v['voteId']?.toString() == uniqueId &&
                      uniqueId.isNotEmpty) ||
                  (v['studentId']?.toString() == sId && sId.isNotEmpty),
            );

            if (masterIndex != -1) {
              studentVotes[masterIndex]['isServed'] = true;
              studentVotes[masterIndex]['choice'] = resolvedMealType;
            }
          });

          _fetchVotes();
          _showSnackBar(
            res['message'] ?? "Meal served successfully!",
            Colors.green,
          );
        } else {
          _showSnackBar(res['message'] ?? "Failed to serve", Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Failed to serve: $e", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => isActionLoading = false);
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
      return Colors.red.shade700;
    if (c.contains("egg")) return Colors.amber.shade800;
    if (c.contains("fish")) return Colors.blue.shade700;
    if (c.contains("veg") || c.contains("paneer")) return Colors.green.shade700;
    return Colors.blueGrey.shade600;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text(
              "Daily Meal Audit",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildSelectors(),
              if (!isLoading) _buildVoteSummary(),
              if (!isLoading) _buildSideBySideChoicesRow(),
              const Divider(height: 1),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepPurple,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchVotes,
                        color: Colors.deepPurple,
                        child: _buildVoteList(),
                      ),
              ),
            ],
          ),
        ),
        if (isActionLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildVoteSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            "VOTED STUDENTS",
            "$totalStudentVotes",
            Colors.deepPurple,
          ),
          _buildSummaryItem(
            "APPROVED GUESTS",
            "+$totalGuestPlates",
            Colors.orange.shade800,
          ),
          _buildSummaryItem(
            "TOTAL PLATES",
            "${totalStudentVotes + totalGuestPlates}",
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSideBySideChoicesRow() {
    final String currentMenu = baseRoutineMenu.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMiniBadge("Regular", regularChoiceCount, Colors.deepPurple),
            if (currentMenu == "chicken")
              _buildMiniBadge("Halal", halalChoiceCount, Colors.red.shade700),
            _buildMiniBadge("Egg Sub", eggChoiceCount, Colors.amber.shade800),
            _buildMiniBadge(
              "Forced Veg",
              vegChoiceCount,
              Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "$count",
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Center(
              child: Text(
                DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            trailing: const Icon(
              Icons.calendar_month,
              color: Colors.deepPurple,
            ),
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
          ),
          const SizedBox(height: 5),
          ToggleButtons(
            isSelected: [selectedTime == "Morning", selectedTime == "Night"],
            onPressed: (index) {
              setState(() => selectedTime = index == 0 ? "Morning" : "Night");
              _fetchVotes();
            },
            borderRadius: BorderRadius.circular(12),
            selectedColor: Colors.white,
            fillColor: Colors.deepPurple,
            color: Colors.deepPurple,
            constraints: const BoxConstraints(minHeight: 34, minWidth: 120),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Morning"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Night"),
              ),
            ],
          ),
          if (!isLoading) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: menuAccentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: menuAccentColor.withOpacity(0.2)),
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
                      "MAIN MENU: ",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "${baseRoutineMenu.toUpperCase()} ",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: menuAccentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: menuAccentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        // ⚡ FIX: Uses fixed local sequence variable populated in state check
                        "MEAL #$mealSequenceNumber",
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteList() {
    if (studentVotes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.no_food_outlined,
                  size: 50,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  "No active menu choices placed yet.",
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: studentVotes.length,
      itemBuilder: (context, index) {
        final item = studentVotes[index];
        final String uniqueId = item['voteId']?.toString() ?? "";
        final bool isServed = item['isServed'] == true;
        final bool isGuest = item['isGuest'] == true;

        final String studentName = item['studentName'] ?? "Unknown Student";
        final String choiceLabel = (item['choice'] ?? "").toString();
        final String photo = item['studentPhoto'] ?? "";

        final String computedChoice = choiceLabel.isEmpty
            ? "WALK-IN (REGULAR)"
            : choiceLabel.replaceAll('_', ' ').toUpperCase();

        // ⚡ FIX: Wrap the Card in a transparent Material widget or set the Card color directly
        // to prevent opaque paint masks from clipping ink ripples and causing framework warnings.
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior:
              Clip.antiAlias, // Clean clipping for smooth rounded corners
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isGuest ? Colors.orange.shade300 : Colors.grey.shade200,
              width: 1,
            ),
          ),
          color: isGuest
              ? Colors.orange.shade50.withOpacity(0.4)
              : (isServed
                    ? Colors.green.shade50.withOpacity(0.3)
                    : Colors.white),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: isGuest
                  ? Colors.orange.shade50
                  : Colors.purple.shade50,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? Icon(
                      isGuest
                          ? Icons.group_outlined
                          : Icons.person_outline_rounded,
                      color: isGuest ? Colors.orange : Colors.purple,
                      size: 18,
                    )
                  : null,
            ),
            title: Text(
              studentName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    _getChoiceIcon(choiceLabel.isEmpty ? "veg" : choiceLabel),
                    size: 14,
                    color: _getChoiceColor(
                      choiceLabel.isEmpty ? "veg" : choiceLabel,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    computedChoice,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getChoiceColor(
                        choiceLabel.isEmpty ? "veg" : choiceLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isServed
                    ? Colors.grey.shade100
                    : Colors.green.shade600,
                foregroundColor: isServed ? Colors.grey : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isServed ? null : () => _markAsServed(uniqueId, item),
              child: Text(
                isServed ? "SERVED" : "SERVE",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
