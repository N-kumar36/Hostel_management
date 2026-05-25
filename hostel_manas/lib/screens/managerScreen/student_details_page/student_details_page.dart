import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/screens/managerScreen/student_details_page/student_details_pages/student_history_view.dart';
import 'package:intl/intl.dart';

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
    // ✅ Fires your getStudentSummary endpoint using the student's unique Mongo ObjectId
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
        title: const Text("Student Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture Circle Avatar
            GestureDetector(
              onTap: _viewFullScreenImage,
              child: Hero(
                tag: 'profile_pic_${s['_id']}',
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.purple.shade50,
                  backgroundImage: s['photoURL'] != null && s['photoURL'].isNotEmpty
                      ? NetworkImage(s['photoURL'])
                      : null,
                  child: s['photoURL'] == null || s['photoURL'].isEmpty
                      ? Text(
                          s['name'] != null && s['name'].isNotEmpty ? s['name'][0].toUpperCase() : "?",
                          style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.purple),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s['name'] ?? "Unknown Student",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              "${s['department'] ?? 'N/A'} | ${s['year'] ?? 'N/A'}",
              style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 32, thickness: 0.8),

            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: Colors.purple)),
                  );
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "Failed to load analytics panel data:\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                
                // ✅ Extracting activeSubscription map tracking your Mongoose schema parameters format
                final subscription = data['activeSubscription'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Live Subscription Status Widget Box
                    _buildSubscriptionDetailsBlock(subscription),
                    
                    const SizedBox(height: 24),
                    const Text(
                      "Activity Metrics Summary",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),

                    GridView.count(
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
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            _buildInfoTile(Icons.assignment_ind, "Registration Number", s['regNum'] ?? "N/A"),
            _buildInfoTile(Icons.email, "Email Address", s['email'] ?? "N/A"),
            _buildInfoTile(Icons.phone, "Phone Number", s['phone'] ?? "N/A"),
          ],
        ),
      ),
    );
  }

  // ✨ NEW WIDGET: Displays individual monthly plan limits vs consumption
  Widget _buildSubscriptionDetailsBlock(dynamic sub) {
    if (sub == null || sub is! Map) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.no_food_rounded, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(
              "No active subscription for this month cycle.",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Safely mapping structures from your StudentSubscription Schema
    final usage = sub['usage'] ?? {};
    final maxLimits = sub['maxLimits'] ?? {};
    final String planType = sub['planType']?.toString() ?? "Routine Plan";
    final String month = sub['month']?.toString() ?? "N/A";
    final String status = sub['status']?.toString().toUpperCase() ?? "PENDING";

    // Mathematical total computation metrics loops
    int totalAllowed = 0;
    int totalUsed = 0;
    maxLimits.forEach((k, v) => totalAllowed += (v as num?)?.toInt() ?? 0);
    usage.forEach((k, v) => totalUsed += (v as num?)?.toInt() ?? 0);
    int totalLeft = totalAllowed - totalUsed;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub Heading Header Title Tag Line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  planType.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.purple, letterSpacing: 0.3),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == "ACTIVE" ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: status == "ACTIVE" ? Colors.green.shade700 : Colors.orange.shade700
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Allowed vs Consumed horizontal analytics counters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricsCounter("Total Quota", "$totalAllowed", Colors.black87),
                    Container(width: 1, height: 18, color: Colors.grey.shade200),
                    _buildMetricsCounter("Consumed", "$totalUsed", Colors.orange.shade800),
                    Container(width: 1, height: 18, color: Colors.grey.shade200),
                    _buildMetricsCounter("Remaining", "$totalLeft", Colors.green.shade700),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Billing Cycle: $month",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20, thickness: 0.6),
                const Text(
                  "Category-wise breakdown balance metrics:",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                
                // Wrapping list map grid layout chips chips view rows
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildCategoryChip("Veg", usage['veg'], maxLimits['veg']),
                    _buildCategoryChip("Chicken", usage['chicken'], maxLimits['chicken']),
                    _buildCategoryChip("Fish", usage['fish'], maxLimits['fish']),
                    _buildCategoryChip("Egg", usage['egg'], maxLimits['egg']),
                    _buildCategoryChip("Paneer", usage['paneer'], maxLimits['paneer']),
                    _buildCategoryChip("Mutton", usage['mutton'], maxLimits['mutton']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCounter(String title, String val, Color highlight) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: highlight)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildCategoryChip(String label, dynamic usedVal, dynamic maxVal) {
    int used = (usedVal as num?)?.toInt() ?? 0;
    int max = (maxVal as num?)?.toInt() ?? 0;
    if (max <= 0) return const SizedBox.shrink();

    bool isFull = used >= max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFull ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isFull ? Colors.red.shade100 : Colors.grey.shade200),
      ),
      child: Text(
        "$label: $used/$max",
        style: TextStyle(
          fontSize: 11, 
          color: isFull ? Colors.red.shade700 : Colors.black87, 
          fontWeight: FontWeight.bold
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

  Widget _statCard(String label, String value, Color color, VoidCallback onTap) {
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
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
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }
}