import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class StudentPaymentScreen extends StatefulWidget {
  const StudentPaymentScreen({super.key});

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  final themeColor = const Color.fromARGB(255, 34, 211, 208);
  final TextEditingController _searchController = TextEditingController();
  final api = ApiService();

  bool isLoading = false;
  String selectedFilter = "All"; // "All", "Paid", "Pending"

  List<dynamic> allPayments = [];
  List<dynamic> filteredPayments = [];

  // Helper method to safely convert values to double
  double _getAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  // Helper method to identify if a payment's month belongs to a past cycle
  bool _isPreviousMonth(dynamic payment) {
    final String paymentMonth = (payment['month'] ?? "").toString().trim();
    if (paymentMonth.isEmpty) return false;

    // Get the current real-time month name and year string (e.g., "May 2026")
    final String currentMonthStr = DateFormat('MMMM yyyy').format(DateTime.now());

    // Returns true if the record belongs to a previous month cycle
    return paymentMonth.toLowerCase() != currentMonthStr.toLowerCase();
  }

  // ✨ UPDATED GETTERS: Separates Current Month Fines from Previous Month Pending Packages
  double get currentFinesTotal => allPayments
      .where((p) => !_isPreviousMonth(p)) // 🚫 Excludes past months
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));
  
  double get currentFinesPaid => allPayments
      .where((p) => p['status']?.toString().toLowerCase() == 'success' && !_isPreviousMonth(p))
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));
      
  double get currentFinesPending => allPayments
      .where((p) {
        final status = p['status']?.toString().toLowerCase();
        final isPendingState = status == 'pending' || status == 'processing';
        return isPendingState && !_isPreviousMonth(p);
      })
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));

  // ✨ NEW GETTER: Calculates total pending balances carried over from previous months
  double get previousMonthPendingAmount => allPayments
      .where((p) {
        final status = p['status']?.toString().toLowerCase();
        final isPendingState = status == 'pending' || status == 'processing';
        return isPendingState && _isPreviousMonth(p); // ✅ Matches past months only
      })
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData);
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterData);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final res = await api.getAllPaymentHistory();
      if (mounted && res['success'] == true) {
        setState(() {
          allPayments = res['data'] ?? [];
        });
        _filterData();
      }
    } catch (e) {
      debugPrint("Error fetching payments: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterData() {
    String query = _searchController.text.toLowerCase().trim();

    setState(() {
      filteredPayments = allPayments.where((payment) {
        final student = payment['studentId'] ?? {};
        final name = (student['name'] ?? "").toString().toLowerCase();
        final status = (payment['status'] ?? "").toString().toLowerCase();

        final matchesName = name.contains(query);

        bool matchesFilter = false;
        if (selectedFilter == "All") {
          matchesFilter = true;
        } else if (selectedFilter == "Paid") {
          matchesFilter = status == "success";
        } else if (selectedFilter == "Pending") {
          matchesFilter = status == "pending" || status == "processing";
        }

        return matchesName && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Student Payments",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ✨ Financial Dashboard Section (Now handles both standard counters + past month debt metrics)
          _buildSummarySection(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search student name...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip("All"),
                    const SizedBox(width: 8),
                    _buildFilterChip("Paid"),
                    const SizedBox(width: 8),
                    _buildFilterChip("Pending"),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 30),

          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : filteredPayments.isEmpty
                    ? const Center(child: Text("No records found", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filteredPayments.length,
                        itemBuilder: (context, index) {
                          final payment = filteredPayments[index];
                          final student = payment['studentId'] ?? {};

                          final String name = student['name'] ?? "Unknown Student";
                          final String photoUrl = student['photoURL'] ?? "";
                          final String title = payment['title'] ?? "Payment Invoice";
                          final amount = payment['amount'] ?? 0;
                          final String screenshotUrl = payment['paymentScreenshot'] ?? "";
                          final String recordMonth = payment['month'] ?? "";
                          
                          final bool isPrevMonth = _isPreviousMonth(payment);
                          final String status = (payment['status'] ?? "pending").toString().toLowerCase();
                          final bool isPaid = status == 'success';

                          String formattedDate = "N/A";
                          if (payment['date'] != null) {
                            try {
                              DateTime date = DateTime.parse(payment['date']).toLocal();
                              formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
                            } catch (e) {
                              debugPrint("Date parse error: $e");
                            }
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              onTap: () {
                                if (screenshotUrl.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentScreenshotScreen(
                                        imageUrl: screenshotUrl,
                                        studentName: name,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("No payment screenshot uploaded for this record."),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                                radius: 24,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                                        style: TextStyle(
                                          color: isPaid ? Colors.green : Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // ✨ UI BADGE: Visually tags previous month logs cleanly from current items
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPrevMonth ? Colors.red.withOpacity(0.08) : Colors.purple.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPrevMonth ? (recordMonth.isNotEmpty ? recordMonth.toUpperCase() : "PAST BILL") : "CURRENT MONTH",
                                      style: TextStyle(
                                        fontSize: 8.5, 
                                        fontWeight: FontWeight.bold, 
                                        color: isPrevMonth ? Colors.red.shade700 : Colors.purple.shade700
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    title, 
                                    style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate, 
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        isPaid ? Icons.check_circle : (status == 'processing' ? Icons.hourglass_bottom : Icons.pending),
                                        size: 14,
                                        color: isPaid ? Colors.green : Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: isPaid ? Colors.green : Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Text(
                                "₹$amount",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryCard("Current Paid", currentFinesPaid, Colors.green),
              const SizedBox(width: 8),
              _buildSummaryCard("Current Pending", currentFinesPending, Colors.purple),
            ],
          ),
          const SizedBox(height: 8),
          // ✨ NEW: Dedicated Full-width card highlighting carried over previous metrics debt balances
          _buildPreviousMonthSummaryCard("PREV. MONTHS PENDING MESS BALANCE", previousMonthPendingAmount),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.withOpacity(0.8), letterSpacing: 0.2),
            ),
            const SizedBox(height: 4),
            Text(
              "₹${amount.toStringAsFixed(0)}", 
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ✨ NEW COMPONENT: Styled alert layout displaying un-cleared past statements balances
  Widget _buildPreviousMonthSummaryCard(String label, double amount) {
    final Color cardColor = amount > 0 ? Colors.red : Colors.grey.shade400;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: amount > 0 ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.w900, 
                color: amount > 0 ? Colors.red.shade900 : Colors.grey.shade700,
                letterSpacing: 0.3
              ),
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w900, 
              color: amount > 0 ? Colors.red.shade700 : Colors.grey.shade600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() => selectedFilter = label);
        _filterData();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? themeColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// PaymentScreenshotScreen remains unchanged...

// ✨ NEW: Screen to display the payment screenshot
class PaymentScreenshotScreen extends StatelessWidget {
  final String imageUrl;
  final String studentName;

  const PaymentScreenshotScreen({
    super.key,
    required this.imageUrl,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("$studentName's Receipt"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: imageUrl.isNotEmpty
            ? InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (context, error, stackTrace) => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Failed to load image", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No screenshot uploaded for this payment.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}