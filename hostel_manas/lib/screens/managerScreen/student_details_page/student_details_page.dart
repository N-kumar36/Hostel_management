import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/screens/managerScreen/student_details_page/student_details_pages/student_history_view.dart';

class StudentDetailsPage extends StatefulWidget {
  final dynamic student;
  const StudentDetailsPage({super.key, required this.student});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  final api = ApiService();
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = api.getStudentSummary(widget.student['_id']);
  }

  void _viewFullScreenImage() {
    final photo = widget.student['photoURL'];
    if (photo == null || photo.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Hero(
                tag: 'profile_pic_${widget.student['_id']}',
                child: InteractiveViewer(
                  child: Image.network(photo, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Student Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _viewFullScreenImage,
              child: Hero(
                tag: 'profile_pic_${s['_id']}',
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.purple.shade50,
                  backgroundImage:
                      s['photoURL'] != null && s['photoURL'].isNotEmpty
                      ? NetworkImage(s['photoURL'])
                      : null,
                  child: s['photoURL'] == null || s['photoURL'].isEmpty
                      ? Text(
                          s['name'] != null && s['name'].isNotEmpty
                              ? s['name'][0].toUpperCase()
                              : "?",
                          style: const TextStyle(
                            fontSize: 45,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s['name'] ?? "Unknown Student",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "${s['department'] ?? 'N/A'} | ${s['year'] ?? 'N/A'}",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Divider(height: 40, thickness: 1),

            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.purple),
                    ),
                  );
                }

                final data = snapshot.data ?? {};

                return GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statCard(
                      "Total Votes",
                      "${data['studentOwnVotes'] ?? 0}",
                      Colors.blue,
                      () => _navigateToHistory('Votes'),
                    ),
                    _statCard(
                      "Guest Meals",
                      "${data['totalGuestVotes'] ?? 0}",
                      Colors.purple,
                      () => _navigateToHistory('Guests'),
                    ),
                    _statCard(
                      "Served Meals",
                      "${data['totalServed'] ?? 0}",
                      Colors.orange,
                      () => _navigateToHistory('Served'),
                    ),
                    _statCard(
                      "Pending Fines",
                      "₹${data['pendingFines'] ?? 0}",
                      Colors.red,
                      () => _navigateToHistory('Fines'),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            _buildInfoTile(
              Icons.assignment_ind,
              "Registration Number",
              s['regNum'] ?? "N/A",
            ),
            _buildInfoTile(Icons.email, "Email Address", s['email'] ?? "N/A"),
            _buildInfoTile(Icons.phone, "Phone Number", s['phone'] ?? "N/A"),
          ],
        ),
      ),
    );
  }

  void _navigateToHistory(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentHistoryView(
          studentId: widget.student['_id'],
          studentName: widget.student['name'] ?? "Student",
          type: type,
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withOpacity(0.1),
          child: Icon(icon, color: Colors.purple, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
