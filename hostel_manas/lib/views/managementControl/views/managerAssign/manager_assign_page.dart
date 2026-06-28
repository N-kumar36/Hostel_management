import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class ManagerAssign extends StatefulWidget {
  const ManagerAssign({super.key});

  @override
  State<ManagerAssign> createState() => _ManagerAssignState();
}

class _ManagerAssignState extends State<ManagerAssign>
    with SingleTickerProviderStateMixin {
  final api = ApiService();
  late TabController _tabController;

  List<dynamic> rawHostelUsers = [];
  List<dynamic> segmentStudents = [];
  List<dynamic> segmentManagers = [];
  List<dynamic> segmentAdmins = [];

  bool isLoading = true;
  String searchQueries = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHostelUsersData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Synchronizes registry items from the server and separates them dynamically by roles
  Future<void> _loadHostelUsersData() async {
    try {
      // Keep loading spinner only on initial launch to avoid intrusive full-screen blocking on pull-to-refresh
      if (rawHostelUsers.isEmpty) {
        setState(() => isLoading = true);
      }

      final List<dynamic>? users = await api.getAllStudentsMnager();

      if (mounted) {
        setState(() {
          if (users != null) {
            rawHostelUsers = users;
            _filterAndBucketsByRole();
          } else {
            rawHostelUsers = [];
            segmentStudents = [];
            segmentManagers = [];
            segmentAdmins = [];
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading system registry coordinates: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _filterAndBucketsByRole() {
    final query = searchQueries.trim().toLowerCase();

    final matchedUsers = rawHostelUsers.where((u) {
      if (query.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final reg = (u['regNum'] ?? '').toString().toLowerCase();
      return name.contains(query) || reg.contains(query);
    }).toList();

    segmentStudents = matchedUsers.where((u) {
      final role = (u['role'] ?? 'student').toString().toLowerCase();
      return role == 'student';
    }).toList();

    segmentManagers = matchedUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      return role == 'manager';
    }).toList();

    segmentAdmins = matchedUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      return role == 'admin';
    }).toList();
  }

  void _applySearchFilter(String queries) {
    searchQueries = queries;
    setState(() {
      _filterAndBucketsByRole();
    });
  }

  /// Sends update payload altering permission layers across the backend
  Future<void> _updateUserRoleAssignment(
    String studentId,
    String targetRole,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.purple)),
    );

    try {
      final response = await api.updateHostelStudentProfile(studentId, {
        "role": targetRole,
      });

      Navigator.pop(context); // Dismiss loading dialog

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Successfully synchronized user permissions to ${targetRole.toUpperCase()}!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadHostelUsersData(); // Hard sync local layout items
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Permission structural change failed: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Staff Board Assignments",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _applySearchFilter,
                    decoration: const InputDecoration(
                      hintText: "Search name or registration standard...",
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.purple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.purple,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: "Students (${segmentStudents.length})"),
                  Tab(text: "Managers (${segmentManagers.length})"),
                  Tab(text: "Admins (${segmentAdmins.length})"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : RefreshIndicator(
              color: Colors.purple,
              onRefresh:
                  _loadHostelUsersData, // ⚡ Pull-to-refresh directly calls your endpoint sync setup
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDynamicSectionListView(
                    segmentStudents,
                    currentSectionType: 'student',
                  ),
                  _buildDynamicSectionListView(
                    segmentManagers,
                    currentSectionType: 'manager',
                  ),
                  _buildDynamicSectionListView(
                    segmentAdmins,
                    currentSectionType: 'admin',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDynamicSectionListView(
    List<dynamic> users, {
    required String currentSectionType,
  }) {
    if (users.isEmpty) {
      // ⚡ Tip: Always wrap empty states in a scrollable widget so the Pull-To-Refresh can still be dragged
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.supervised_user_circle_outlined,
                size: 44,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                "No users found inside ${currentSectionType.toUpperCase()} directory.",
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(), // Ensures scrolling is always engaged for pull-to-refresh
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final String name = user['name'] ?? "Unknown Student";
        final String regNum = user['regNum'] ?? "N/A";
        final String dept = user['department'] ?? "N/A";
        final String? photo = user['photoURL'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.purple.shade50,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? NetworkImage(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    )
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Reg: $regNum\n$dept",
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.shield_outlined, color: Colors.purple),
              tooltip: "Modify Permissions",
              onSelected: (targetRole) =>
                  _updateUserRoleAssignment(user['_id'], targetRole),
              itemBuilder: (context) => [
                if (currentSectionType != 'student')
                  const PopupMenuItem(
                    value: 'student',
                    child: Text("Demote to Student"),
                  ),
                if (currentSectionType != 'manager')
                  const PopupMenuItem(
                    value: 'manager',
                    child: Text("Promote to Manager"),
                  ),
                if (currentSectionType != 'admin')
                  const PopupMenuItem(
                    value: 'admin',
                    child: Text("Promote to Admin"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
