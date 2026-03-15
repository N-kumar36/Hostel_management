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

  // ✅ Computed getters for the summary counters
  int get servedCount => _allVotes.where((v) => v['isServed'] == true).length;
  int get notServedCount =>
      _allVotes.where((v) => v['isServed'] == false).length;

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
      bool servedA = a['isServed'] ?? false;
      bool servedB = b['isServed'] ?? false;
      if (servedA == servedB) return 0;
      return servedA ? 1 : -1;
    });
    _onSearchChanged();
  }

  Future<void> _handleServe(String? voteId, bool currentValue) async {
    if (voteId == null || voteId.isEmpty || processingId != null) {
      _showSnackBar("Invalid Vote ID", Colors.red);
      return;
    }

    setState(() => processingId = voteId);

    try {
      final res = await api.updateServeStatus(voteId);

      if (mounted) {
        if (res['success'] == true) {
          final bool serverStatus = res['isServed'] ?? !currentValue;

          setState(() {
            final masterIndex = _allVotes.indexWhere(
              (v) => v['voteId']?.toString() == voteId,
            );

            if (masterIndex != -1) {
              _allVotes[masterIndex]['isServed'] = serverStatus;
            }

            _sortAndFilterList();
            processingId = null;
          });

          _showSnackBar(
            serverStatus ? "Meal served!" : "Status updated",
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
        duration: const Duration(seconds: 1),
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
        child: Text("No records found", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _filteredVotes.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, i) {
        final vote = _filteredVotes[i];
        final String id = vote['voteId']?.toString() ?? "";
        final bool served = vote['isServed'] ?? false;
        final bool isThisItemLoading = processingId == id;

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
              "Choice: ${vote['choice']?.toUpperCase() ?? 'N/A'}",
              style: TextStyle(
                color: served ? Colors.grey : Colors.orange.shade700,
              ),
            ),
            // ...existing code...
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
                    onChanged: (val) => _handleServe(id, served),
                  ),
            // ...existing code...
          ),
        );
      },
    );
  }
}
