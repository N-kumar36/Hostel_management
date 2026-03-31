import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class VoteStatusSelectionPage extends StatefulWidget {
  const VoteStatusSelectionPage({super.key});

  @override
  State<VoteStatusSelectionPage> createState() => _VoteStatusSelectionPageState();
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
      final response = await api.getDetailedVotesByDate(formattedDate, selectedTime);
      if (mounted) {
        setState(() {
          // The backend sends everyone. We filter it to ONLY show those who voted.
          // We assume a user has voted if their 'choice' string is not empty.
          final allData = response['data'] ?? [];
          
          studentVotes = allData.where((item) {
             final choice = item['choice']?.toString() ?? "";
             return choice.isNotEmpty; 
          }).toList();

          totalGuestPlates = studentVotes.where((item) => item['isGuest'] == true).length;
          totalStudentVotes = studentVotes.where((item) => item['isGuest'] == false).length;
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

      final res = await api.updateServeStatus(vId, sId, formattedDate, selectedTime);

      if (mounted) {
        if (res['success'] == true) {
          final String resolvedMealType = res['mealType'] ?? "Served";

          setState(() {
            final masterIndex = studentVotes.indexWhere((v) =>
                (v['voteId']?.toString() == uniqueId) ||
                (v['studentId']?.toString() == uniqueId) ||
                (v['_id']?.toString() == uniqueId));

            if (masterIndex != -1) {
              studentVotes[masterIndex]['isServed'] = true; 

              if (studentVotes[masterIndex]['choice'] == null || studentVotes[masterIndex]['choice'] == "") {
                studentVotes[masterIndex]['choice'] = resolvedMealType;
              }
            }
          });

          _showSnackBar(res['message'] ?? "Meal served successfully!", Colors.green);
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text("Daily Meal Audit", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              _buildSelectors(),
              if (!isLoading) _buildVoteSummary(),
              const Divider(height: 1),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                    : RefreshIndicator(
                        onRefresh: _fetchVotes,
                        child: _buildVoteList(),
                      ),
              ),
            ],
          ),
        ),
        if (isActionLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildVoteSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem("STUDENTS", "$totalStudentVotes", Colors.deepPurple),
          _summaryItem("GUESTS", "+$totalGuestPlates", Colors.orange.shade800),
          _summaryItem("TOTAL PLATES", "${totalStudentVotes + totalGuestPlates}", Colors.green),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSelectors() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 15, top: 5),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Center(
              child: Text(
                DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            trailing: const Icon(Icons.calendar_month, color: Colors.deepPurple),
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
          const SizedBox(height: 10),
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
            constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Morning")),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Night")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteList() {
    if (studentVotes.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(child: Text("No records found for this slot.", style: TextStyle(color: Colors.grey))),
        ],
      );
    }

    return ListView.builder(
      itemCount: studentVotes.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final item = studentVotes[index];
        
        final String uniqueId = item['voteId']?.toString() ??
            item['studentId']?.toString() ??
            item['_id']?.toString() ??
            "";

        final bool isGuest = item['isGuest'] ?? false;
        final bool isServed = item['isServed'] ?? false;

        final String choiceStr = item['choice']?.toString() ?? "";

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isGuest ? Colors.orange.shade300 : Colors.grey.shade200,
              width: isGuest ? 1.5 : 1,
            ),
          ),
          color: isGuest 
              ? Colors.orange.shade50.withOpacity(0.4) 
              : (isServed ? Colors.green.shade50.withOpacity(0.3) : Colors.white),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: isGuest ? Colors.orange : Colors.deepPurple.shade50,
              backgroundImage: (!isGuest && item['studentPhoto'] != null && item['studentPhoto'] != "")
                  ? NetworkImage(item['studentPhoto'])
                  : null,
              child: isGuest 
                ? const Icon(Icons.group_add, color: Colors.white)
                : (item['studentPhoto'] == null || item['studentPhoto'] == "" 
                    ? const Icon(Icons.person, color: Colors.deepPurple) 
                    : null),
            ),
            title: Text(
              item['studentName'] ?? "Unknown",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isGuest ? Colors.orange.shade900 : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  isGuest ? "Individual Guest Plate" : (item['studentEmail'] ?? ""),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  "Choice: ${choiceStr.toUpperCase()}",
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.deepPurple.shade300 
                  ),
                ),
              ],
            ),
            trailing: isServed 
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    Text("SERVED", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                )
              : IconButton(
                  icon: Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
                  onPressed: () => _markAsServed(uniqueId, item),
                ),
          ),
        );
      },
    );
  }
}