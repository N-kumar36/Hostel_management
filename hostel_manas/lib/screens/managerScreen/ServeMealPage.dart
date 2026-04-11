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

  // ✨ FIXED: Computed getters for the summary counters
  int get servedCount => _allVotes.where((v) => v['isServed'] == true).length;
  
  int get notServedCount => _allVotes.where((v) {
        bool isServed = v['isServed'] == true;
        String choice = v['choice']?.toString() ?? "";
        bool hasVoted = choice.isNotEmpty;
        // ONLY count them as Pending if they haven't been served AND they actually voted
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
    String query = _searchController.text.toLowerCase();
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
      // Helper function to assign priority
      int getPriority(Map<String, dynamic> vote) {
        bool isServed = vote['isServed'] ?? false;
        String choice = vote['choice']?.toString() ?? "";
        bool hasVoted = choice.isNotEmpty;

        if (!isServed && hasVoted) return 1; // Top priority: Voted, but not yet served
        if (isServed) return 2;              // Middle priority: Served
        return 3;                            // Lowest priority: Not Voted (Walk-ins)
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
    if (uniqueId.isEmpty || processingId != null) {
      _showSnackBar("Invalid ID", Colors.red);
      return;
    }

    setState(() => processingId = uniqueId);

    try {
      final String? vId = studentData['voteId']?.toString();
      final String sId = studentData['studentId']?.toString() ?? "";
      String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);

      final res = await api.updateServeStatus(
        vId,
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
                  (v['voteId']?.toString() == uniqueId) ||
                  (v['studentId']?.toString() == uniqueId) ||
                  (v['_id']?.toString() == uniqueId),
            );

            if (masterIndex != -1) {
              _allVotes[masterIndex]['isServed'] = serverStatus;

              if (returnedVoteId != null) {
                _allVotes[masterIndex]['voteId'] = returnedVoteId;
              }

              if (serverStatus &&
                  (_allVotes[masterIndex]['choice'] == null ||
                      _allVotes[masterIndex]['choice'] == "")) {
                _allVotes[masterIndex]['choice'] = resolvedMealType;
              }
            }

            _sortAndFilterList();
            processingId = null;
          });

          _showSnackBar(
            res['message'] ?? (serverStatus ? "Meal served!" : "Status updated"),
            Colors.green,
          );
        } else {
          setState(() => processingId = null);
          String errorMsg = res['message'] ?? "Server rejected update";
          _showSnackBar(errorMsg, Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => processingId = null);
        _showSnackBar("Connection Error: $e", Colors.red);
      }
    }
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
                : RefreshIndicator(onRefresh: _fetchData, child: _buildList()),
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
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.orange.withOpacity(0.1),
      child: Row(
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
              items: [
                "Morning",
                "Night",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
            "PENDING",
            notServedCount.toString(), // ✨ Now uses the updated logic
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
        child: Text("No records found", style: TextStyle(color: Colors.grey)),
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

        final bool served = vote['isServed'] ?? false;
        final bool isThisItemLoading = processingId == uniqueId;

        final String choiceStr = vote['choice']?.toString() ?? "";
        final bool hasVoted = choiceStr.isNotEmpty;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: served ? 0 : 2,
          color: served ? Colors.green.withOpacity(0.05) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: served
                ? BorderSide(color: Colors.green.withOpacity(0.2))
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: served
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              backgroundImage:
                  (vote['studentPhoto'] != null && vote['studentPhoto'] != "")
                  ? NetworkImage(vote['studentPhoto'])
                  : null,
              child:
                  (vote['studentPhoto'] == null || vote['studentPhoto'] == "")
                  ? Text(
                      vote['studentName']?[0].toUpperCase() ?? "?",
                      style: TextStyle(
                        color: served ? Colors.green : Colors.orange,
                      ),
                    )
                  : null,
            ),
            title: Text(
              vote['studentName'] ?? "Unknown",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: served ? TextDecoration.lineThrough : null,
                color: served ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Text(
              hasVoted ? "Choice: ${choiceStr.toUpperCase()}" : "NOT VOTED",
              style: TextStyle(
                color: served
                    ? Colors.grey
                    : (hasVoted ? Colors.orange.shade700 : Colors.red.shade600),
                fontWeight: hasVoted ? FontWeight.normal : FontWeight.bold,
              ),
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