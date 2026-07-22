import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/views/managementControl/views/allStudent/student_details_page.dart';

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

  final TextEditingController searchController = TextEditingController();
  String selectedDept = "All";
  String selectedYear = "All";

  final List<String> departmentList = [
    "All",
    "B.Tech",
    "M.Tech",
    "B.Sc",
    "M.Sc",
    "BCA",
    "MCA",
    "BBA",
    "MBA",
    "LLB",
    "MA",
    "MSE",
    "PhD",
    "Others",
  ];

  final List<String> yearList = [
    "All",
    "1st Year",
    "2nd Year",
    "3rd Year",
    "4th Year",
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await api.getAllHostelStudent();
      if (mounted) {
        setState(() {
          allStudents = data;
          isLoading = false;
        });
        _applySearchAndFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  void _applySearchAndFilter() {
    final query = searchController.text.trim().toLowerCase();
    final deptFilter = selectedDept.toLowerCase();
    final yearFilter = selectedYear.toLowerCase();

    setState(() {
      filteredStudents = allStudents.where((student) {
        final name = (student['name'] ?? "").toString().toLowerCase();
        final regNum = (student['regNum'] ?? "").toString().toLowerCase();
        final email = (student['email'] ?? "").toString().toLowerCase();
        final department = (student['department'] ?? "")
            .toString()
            .toLowerCase();
        final year = (student['year'] ?? "").toString().toLowerCase();

        final matchesSearch =
            query.isEmpty ||
            name.contains(query) ||
            regNum.contains(query) ||
            email.contains(query);

        final matchesDept = selectedDept == "All" || department == deptFilter;
        final matchesYear = selectedYear == "All" || year == yearFilter;

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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (val) => _applySearchAndFilter(),
                  decoration: InputDecoration(
                    hintText: "Search name, reg, or email...",
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.purple,
                      size: 22,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              searchController.clear();
                              _applySearchAndFilter();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(departmentList, (val) {
                        if (val != null) {
                          selectedDept = val;
                          _applySearchAndFilter();
                        }
                      }, selectedDept),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFilterDropdown(yearList, (val) {
                        if (val != null) {
                          selectedYear = val;
                          _applySearchAndFilter();
                        }
                      }, selectedYear),
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
    List<String> items,
    ValueChanged<String?> onChanged,
    String currentVal,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.purple),
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

  Widget _buildStudentTile(dynamic student) {
    final String photo = student['photoURL'] ?? "";
    final String initial =
        student['name'] != null && student['name'].toString().isNotEmpty
        ? student['name'][0].toUpperCase()
        : "?";

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // If your StudentDetailsPage depends on a full fresh fetch,
          // ensure the student object is handled cleanly there.
          final bool? didModify = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailsPage(student: student),
            ),
          );
          if (didModify == true) {
            _fetchData(); // Triggers a reload if a user was deleted/edited
          }
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.purple.withOpacity(0.1),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            student['name'] ?? "Unknown Student",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "${student['department'] ?? 'N/A'} | ${student['year'] ?? 'N/A'}\nReg: ${student['regNum'] ?? 'N/A'}",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 14,
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
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No students matched criteria",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isOffline, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 56,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isOffline ? "No Internet Connection" : "Something went wrong",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Retry Connection"),
            ),
          ],
        ),
      ),
    );
  }
}
