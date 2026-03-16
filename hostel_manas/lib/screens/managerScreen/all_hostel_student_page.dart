import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/screens/managerScreen/student_details_page/student_details_page.dart';

class AllHostelStudentPage extends StatefulWidget {
  const AllHostelStudentPage({super.key});

  @override
  State<AllHostelStudentPage> createState() => _AllHostelStudentPageState();
}

class _AllHostelStudentPageState extends State<AllHostelStudentPage> {
  final api = ApiService();

  List<dynamic> allStudents = [];
  List<dynamic> filteredStudents = [];
  bool isLoading = true;
  String? errorMessage;

  // Search and Filter controllers/values
  TextEditingController searchController = TextEditingController();
  String selectedDept = "All";
  String selectedYear = "All";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await api.getAllHostelStudent();
      setState(() {
        allStudents = data;
        filteredStudents = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  void _applySearchAndFilter() {
    String query = searchController.text.toLowerCase();

    setState(() {
      filteredStudents = allStudents.where((student) {
        // Search Logic (Name, Reg, or Email)
        final matchesSearch =
            student['name'].toString().toLowerCase().contains(query) ||
            student['regNum'].toString().toLowerCase().contains(query) ||
            student['email'].toString().toLowerCase().contains(query);

        // Filter Logic (Department)
        final matchesDept =
            selectedDept == "All" || student['department'] == selectedDept;

        // Filter Logic (Year)
        final matchesYear =
            selectedYear == "All" || student['year'] == selectedYear;

        return matchesSearch && matchesDept && matchesYear;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Hostel Students",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: searchController,
                  onChanged: (val) => _applySearchAndFilter(),
                  decoration: InputDecoration(
                    hintText: "Search name, reg, or email...",
                    prefixIcon: const Icon(Icons.search, color: Colors.purple),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 8),
                // Filter Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        "Dept",
                        ["All", "B.Tech", "MBA", "MCA", "B.Sc"],
                        (val) {
                          selectedDept = val!;
                          _applySearchAndFilter();
                        },
                        selectedDept,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown(
                        "Year",
                        ["All", "1st Year", "2nd Year", "3rd Year", "4th Year"],
                        (val) {
                          selectedYear = val!;
                          _applySearchAndFilter();
                        },
                        selectedYear,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : errorMessage != null
          ? _buildErrorState(
              errorMessage!.contains("SocketException"),
              errorMessage!,
            )
          : filteredStudents.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: Colors.purple,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) =>
                    _buildStudentTile(filteredStudents[index]),
              ),
            ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    List<String> items,
    ValueChanged<String?> onChanged,
    String currentVal,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.purple,
            fontWeight: FontWeight.w600,
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildStudentTile(dynamic student) {
    final String photo = student['photoURL'] ?? "";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        // ✅ ADD THIS
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailsPage(student: student,),
            ),
          );
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple.withOpacity(0.1),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? Text(
                    student['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.purple),
                  )
                : null,
          ),
          title: Text(
            student['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "${student['department']} | ${student['year']}\nReg: ${student['regNum']}",
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No students match your criteria",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isOffline, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.error_outline,
            size: 50,
            color: Colors.red,
          ),
          Text(isOffline ? "No Internet" : "Error occurred"),
          TextButton(onPressed: _fetchData, child: const Text("Retry")),
        ],
      ),
    );
  }

  void _showStudentDetails(dynamic student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Student Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _detailRow(Icons.phone, "Phone", student['phone']),
            _detailRow(Icons.email, "Email", student['email']),
            // _detailRow(Icons.numbers, "Roll No", student['roll'] ?? "N/A"),
            _detailRow(Icons.assignment_ind, "Registration", student['regNum']),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.purple),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
