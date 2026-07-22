import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:HostelMess/services/api_service.dart';
import 'student_meal_audit_page.dart';

class StudentDetailsPage extends StatefulWidget {
  final dynamic student;
  const StudentDetailsPage({super.key, required this.student});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  final api = ApiService();

  Map<String, dynamic> localStudentData = {};
  Map<String, dynamic> cycleFilteredSummary = {};

  bool isLoadingData = true;
  bool isProcessingChanges = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    localStudentData = Map<String, dynamic>.from(widget.student);
    print("Student data ${localStudentData}");
    _initializeCycleAndProfileMetrics();
  }

  /// then isolates targeted analytical summary metrics.
  Future<void> _initializeCycleAndProfileMetrics() async {
    try {
      if (mounted) {
        setState(() {
          isLoadingData = true;
          loadError = null;
        });
      }

      final userResponse = await api.getStudentById(localStudentData['_id']);

      if (mounted) {
        setState(() {
          localStudentData = Map<String, dynamic>.from(
            userResponse['data'] ?? userResponse,
          );
          isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Pipeline Error initializing targeted audit elements: $e");
      if (mounted) {
        setState(() {
          loadError = e.toString();
          isLoadingData = false;
        });
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    try {
      return DateFormat(
        'dd MMM yyyy, hh:mm a',
      ).format(DateTime.parse(timestamp.toString()));
    } catch (_) {
      return timestamp.toString();
    }
  }

  void _showManagerEditSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: localStudentData['name']?.toString(),
    );
    final emailController = TextEditingController(
      text: localStudentData['email']?.toString(),
    );
    final phoneController = TextEditingController(
      text: localStudentData['phone']?.toString(),
    );
    final regController = TextEditingController(
      text: localStudentData['regNum']?.toString(),
    );
    final roomController = TextEditingController(
      text: localStudentData['roomNumber']?.toString(),
    );
    final deptController = TextEditingController(
      text: localStudentData['department']?.toString(),
    );

    String currentYear = localStudentData['year'] ?? "1st Year";
    String rawStatus = localStudentData['status'] ?? "unverified";
    if (rawStatus == "approve" || rawStatus == "active") rawStatus = "active";
    if (rawStatus == "pending" || rawStatus == "unverified")
      rawStatus = "unverified";
    String currentStatus = rawStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Edit Student Schema Data",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Full Name",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "Email Address",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: "Phone Number",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: regController,
                              decoration: const InputDecoration(
                                labelText: "Reg Num",
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: roomController,
                              decoration: const InputDecoration(
                                labelText: "Room Number",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deptController,
                        decoration: const InputDecoration(
                          labelText: "Department",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: currentYear,
                        decoration: const InputDecoration(
                          labelText: "Academic Year",
                          border: OutlineInputBorder(),
                        ),
                        items: ["1st Year", "2nd Year", "3rd Year", "4th Year", "5th Year"]
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (v) => setModalState(() => currentYear = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: currentStatus,
                        decoration: const InputDecoration(
                          labelText: "Hostel Status",
                          border: OutlineInputBorder(),
                        ),
                        items:
                            ["unverified", "active", "passout", "left_hostel"]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.toUpperCase()),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) =>
                            setModalState(() => currentStatus = v!),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final updatedPayload = {
                                "name": nameController.text.trim(),
                                "email": emailController.text
                                    .trim()
                                    .toLowerCase(),
                                "phone": phoneController.text.trim(),
                                "regNum": regController.text.trim(),
                                "roomNumber": roomController.text.trim(),
                                "department": deptController.text.trim(),
                                "year": currentYear,
                                "status": currentStatus,
                              };
                              Navigator.pop(context);
                              _updateStudentSchema(updatedPayload);
                            }
                          },
                          child: const Text(
                            "Commit Schema Save Changes",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStudentSchema(Map<String, dynamic> payload) async {
    try {
      setState(() => isProcessingChanges = true);
      final response = await api.updateHostelStudentProfile(
        localStudentData['_id'],
        payload,
      );
      if (response['success'] == true) {
        _initializeCycleAndProfileMetrics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating schema profiles: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessingChanges = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.orange;
    if (localStudentData['status'] == 'active' ||
        localStudentData['status'] == 'approve')
      statusColor = Colors.green;
    if (localStudentData['status'] == 'passout') statusColor = Colors.blue;
    if (localStudentData['status'] == 'left_hostel') statusColor = Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Student Dashboard Profile",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_note_rounded,
              color: Colors.purple,
              size: 26,
            ),
            onPressed: _showManagerEditSheet,
            tooltip: "Edit Fields",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoadingData || isProcessingChanges
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.purple,
                strokeWidth: 3,
              ),
            )
          : loadError != null
          ? _buildErrorScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderViewBlock(statusColor),
                  const SizedBox(height: 20),

                  _buildMealAuditNavigatorTile(),

                  const SizedBox(height: 16),

                  _buildSectionHeading("Core Document Registry Properties"),
                  const SizedBox(height: 10),
                  _buildCoreFieldsGroup(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderViewBlock(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.purple.shade50,
            backgroundImage:
                (localStudentData['photoURL'] != null &&
                    localStudentData['photoURL'].isNotEmpty)
                ? NetworkImage(localStudentData['photoURL'])
                : null,
            child:
                (localStudentData['photoURL'] == null ||
                    localStudentData['photoURL'].isEmpty)
                ? Text(
                    localStudentData['name'] != null
                        ? localStudentData['name'][0].toUpperCase()
                        : "?",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.purple,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            localStudentData['name'] ?? "Unknown Student",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${localStudentData['department'] ?? 'N/A'} • ${localStudentData['year'] ?? 'N/A'}",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _badgeWidget(
                (localStudentData['role'] ?? 'STUDENT')
                    .toString()
                    .toUpperCase(),
                Colors.purple.shade700,
                Colors.purple.shade50,
              ),
              const SizedBox(width: 8),
              _badgeWidget(
                (localStudentData['status'] ?? 'UNVERIFIED')
                    .toString()
                    .toUpperCase(),
                statusColor,
                statusColor.withOpacity(0.08),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealAuditNavigatorTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade50,
          child: const Icon(
            Icons.analytics_rounded,
            color: Colors.purple,
            size: 20,
          ),
        ),
        title: const Text(
          "Student Audit Breakdown Quota",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),

        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.purple),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentMealAuditPage(
                studentName: localStudentData['name'] ?? "Student",
                studentId: localStudentData['_id'],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoreFieldsGroup() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _infoFieldTile(
            Icons.assignment_ind_outlined,
            "Department",
            localStudentData['department'] ?? "N/A",
          ),

          _infoFieldTile(
            Icons.assignment_ind_outlined,
            "Registration Identifier",
            localStudentData['regNum'] ?? "N/A",
          ),
          _infoFieldTile(
            Icons.alternate_email_rounded,
            "Email Address Coordinate",
            localStudentData['email'] ?? "N/A",
          ),
          _infoFieldTile(
            Icons.phone_iphone_rounded,
            "Phone Contact Connection",
            localStudentData['phone'] ?? "N/A",
          ),
          _infoFieldTile(
            Icons.room_preferences_outlined,
            "Assigned Room Location",
            localStudentData['roomNumber'] ?? "Not Assigned Room",
          ),
          _infoFieldTile(
            Icons.edit_calendar_rounded,
            "Profile Last Modified",
            _formatTimestamp(localStudentData['updatedAt']),
          ),
        ],
      ),
    );
  }

  Widget _infoFieldTile(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.purple.shade300, size: 18),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _badgeWidget(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Colors.black54,
        letterSpacing: 0.2,
      ),
    ),
  );

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 10),
            Text(
              "Failed to initialize target sync state values: $loadError",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _initializeCycleAndProfileMetrics,
              child: const Text(
                "Retry Connection Pipeline",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
