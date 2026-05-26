import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class ServeMealPage extends StatefulWidget {
  const ServeMealPage({super.key});

  @override
  State<ServeMealPage> createState() => _ServeMealPageState();
}

class _ServeMealPageState extends State<ServeMealPage> {
  final api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedTime = "Morning";
  List<dynamic> _allVotes = [];
  List<dynamic> _filteredVotes = [];

  bool isLoading = false;
  String? processingId;
  String baseRoutineMenu = "veg"; // Tracks live slot base menu item

  // Computed getters for the summary counters
  int get servedCount => _allVotes.where((v) => v['isServed'] == true).length;

  int get notServedCount => _allVotes.where((v) {
    bool isServed = v['isServed'] == true;
    String choice = v['choice']?.toString() ?? "";
    bool hasVoted = choice.isNotEmpty;
    return !isServed && hasVoted;
  }).length;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredVotes = _allVotes.where((vote) {
        final name = (vote['studentName'] ?? "").toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);
    try {
      final res = await api.getDetailedVotesByDate(formattedDate, selectedTime);
      if (mounted) {
        setState(() {
          _allVotes = res['data'] ?? [];

          // Dynamically capture the true base menu configuration snapshot
          if (_allVotes.isNotEmpty && _allVotes[0]['menuItem'] != null) {
            baseRoutineMenu = _allVotes[0]['menuItem'].toString().toLowerCase();
          } else {
            baseRoutineMenu = "veg";
          }

          _sortAndFilterList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar("Error fetching data: $e", Colors.red);
      }
    }
  }

  void _sortAndFilterList() {
    _allVotes.sort((a, b) {
      int getPriority(Map<String, dynamic> vote) {
        bool isServed = vote['isServed'] ?? false;
        String choice = vote['choice']?.toString() ?? "";
        bool hasVoted = choice.isNotEmpty;

        if (!isServed && hasVoted) return 1; // Priority 1: Voted, but Pending
        if (isServed) return 2; // Priority 2: Served
        return 3; // Priority 3: Not Voted Walk-ins
      }

      return getPriority(a).compareTo(getPriority(b));
    });

    _onSearchChanged();
  }

  Future<void> _handleServe(
    String uniqueId,
    bool currentValue,
    Map<String, dynamic> studentData,
  ) async {
    final String? vId = studentData['voteId']?.toString();
    final String sId = studentData['studentId']?.toString() ?? "";

    final String executionTrackingId = (vId != null && vId.isNotEmpty)
        ? vId
        : sId;

    if (executionTrackingId.isEmpty || processingId != null) {
      _showSnackBar("Invalid transaction target profiles", Colors.red);
      return;
    }

    setState(() => processingId = executionTrackingId);

    try {
      String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);

      final res = await api.updateServeStatus(
        (vId != null && vId.isNotEmpty) ? vId : "",
        sId,
        formattedDate,
        selectedTime,
      );

      if (mounted) {
        if (res['success'] == true) {
          final bool serverStatus = res['isServed'] ?? !currentValue;
          final String resolvedMealType = res['mealType'] ?? "Served";
          final String? returnedVoteId = res['voteId']?.toString();

          setState(() {
            final masterIndex = _allVotes.indexWhere(
              (v) =>
                  (v['voteId']?.toString() == executionTrackingId &&
                      executionTrackingId.isNotEmpty) ||
                  (v['studentId']?.toString() == sId && sId.isNotEmpty),
            );

            if (masterIndex != -1) {
              _allVotes[masterIndex]['isServed'] = serverStatus;

              if (returnedVoteId != null) {
                _allVotes[masterIndex]['voteId'] = returnedVoteId;
                _allVotes[masterIndex]['choice'] = resolvedMealType;
              }
            }

            _sortAndFilterList();
            processingId = null;
          });

          _showSnackBar(
            res['message'] ??
                (serverStatus ? "Meal served!" : "Status updated"),
            Colors.green,
          );
        } else {
          setState(() => processingId = null);
          _showSnackBar(
            res['message'] ?? "Server rejected updates",
            Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => processingId = null);
        _showSnackBar("Connection Error: $e", Colors.red);
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
    return Icons.grass_rounded;
  }

  Color _getChoiceColor(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken") || c.contains("mutton"))
      return Colors.red.shade700;
    if (c.contains("egg")) return Colors.amber.shade800;
    if (c.contains("fish")) return Colors.blue.shade700;
    return Colors.green.shade700;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Serve Student Meals",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSummarySection(),
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: Colors.orange,
                    child: _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search student name...",
          prefixIcon: const Icon(Icons.search, color: Colors.orange),
          filled: true,
          fillColor: Colors.orange.withOpacity(0.05),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final Color menuAccentColor = _getChoiceColor(baseRoutineMenu);

    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.orange.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                      _fetchData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(color: Colors.orange),
                ),
                child: DropdownButton<String>(
                  value: selectedTime,
                  underline: const SizedBox(),
                  items: ["Morning", "Night"]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedTime = val);
                      _fetchData();
                    }
                  },
                ),
              ),
            ],
          ),

          if (!isLoading) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: menuAccentColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getChoiceIcon(baseRoutineMenu),
                    color: menuAccentColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "CURRENT BASE MENU: ",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    baseRoutineMenu.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: menuAccentColor,
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

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          _buildCounterCard(
            "SERVED",
            servedCount.toString(),
            Colors.green,
            Icons.check_circle_outline,
          ),
          const SizedBox(width: 12),
          _buildCounterCard(
            "PENDING VOTES",
            notServedCount.toString(),
            Colors.orange,
            Icons.pending_actions,
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.8),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Icon(icon, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_filteredVotes.isEmpty) {
      return const Center(
        child: Text(
          "No operational records logged",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredVotes.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, i) {
        final vote = _filteredVotes[i];

        final String uniqueId =
            vote['voteId']?.toString() ??
            vote['studentId']?.toString() ??
            vote['_id']?.toString() ??
            "";

        final bool served = vote['isServed'] == true;
        final bool isThisItemLoading = processingId == uniqueId;

        final String choiceStr = vote['choice']?.toString() ?? "";
        final bool hasVoted = choiceStr.isNotEmpty;
        final bool isGuest = vote['isGuest'] == true;

        final String currentChoice = hasVoted ? choiceStr : baseRoutineMenu;
        final Color choiceColor = isGuest
            ? Colors.orange.shade800
            : _getChoiceColor(currentChoice);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: served ? 0 : 1.5,
          color: isGuest
              ? Colors.orange.shade50.withOpacity(0.3)
              : (served ? Colors.green.withOpacity(0.04) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: served
                  ? Colors.green.withOpacity(0.2)
                  : (isGuest
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.grey.shade100),
              width: 1,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: served
                  ? Colors.green.shade100
                  : (isGuest ? Colors.orange.shade100 : Colors.orange.shade50),
              backgroundImage:
                  (vote['studentPhoto'] != null && vote['studentPhoto'] != "")
                  ? NetworkImage(vote['studentPhoto'])
                  : null,
              child:
                  (vote['studentPhoto'] == null || vote['studentPhoto'] == "")
                  ? Icon(
                      isGuest ? Icons.group_add : _getChoiceIcon(currentChoice),
                      color: served ? Colors.green : choiceColor,
                      size: 20,
                    )
                  : null,
            ),
            title: Text(
              vote['studentName'] ?? "Unknown Student",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: served ? TextDecoration.lineThrough : null,
                color: served ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                // ✨ NEW STATUS METADATA: Explicitly distinguishes who has voted vs walk-in counters
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? Colors.blue.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasVoted ? "PRE-VOTED AT SYSTEM" : "WALK-IN ENTRANT",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: hasVoted
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getChoiceIcon(currentChoice),
                      color: served ? Colors.grey : choiceColor,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGuest
                          ? "GUEST CHOICE: ${choiceStr.toUpperCase()}"
                          : (hasVoted
                                ? "CHOICE: ${choiceStr.toUpperCase()}"
                                // ✨ FIXED VISUAL LABEL: Remapped placeholder parameter text label
                                : "NOT VOTED (WALK-IN: ${baseRoutineMenu.toUpperCase()})"),
                      style: TextStyle(
                        color: served ? Colors.grey : choiceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: isThisItemLoading
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    ),
                  )
                : Switch(
                    value: served,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.shade200,
                    onChanged: (val) => _handleServe(uniqueId, served, vote),
                  ),
          ),
        );
      },
    );
  }
}
