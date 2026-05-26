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
  
  // Custom filter toggles: "All", "Current", "Previous"
  String selectedFilter = "All"; 

  List<dynamic> allPayments = [];
  List<dynamic> filteredPayments = [];
  String? activeSubscriptionId;

  // Helper method to safely convert values to double weights
  double _getAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  // CORE LOGIC: Identifies if a record belongs to an exhausted previous cycle block
  bool _isPreviousCycle(dynamic payment) {
    if (payment is Map && payment.containsKey('belongsToCurrentCycle')) {
      return payment['belongsToCurrentCycle'] == false;
    }
    return payment['isMealPackage'] == true;
  }

  // --- Dynamic Financial Summary Getters ---

  // 1. Grand Total: Total outstanding balance combined across all timelines
  double get totalOutstandingDebt => allPayments
      .where((p) {
        final status = p['status']?.toString().toLowerCase();
        return status == 'pending' || status == 'processing';
      })
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));

  // 2. Active Month: Total successfully cleared paid balances for the running cycle
  double get currentFinesPaid => allPayments
      .where((p) => p['status']?.toString().toLowerCase() == 'success' && !_isPreviousCycle(p))
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));
      
  // 3. Active Month: Total pending balances left to be collected for the current package sequence
  double get currentFinesPending => allPayments
      .where((p) {
        final status = p['status']?.toString().toLowerCase();
        final isPendingState = status == 'pending' || status == 'processing';
        return isPendingState && !_isPreviousCycle(p);
      })
      .fold(0.0, (sum, p) => sum + _getAmount(p['amount']));

  // 4. Past Balance: Total pending debt carried over from old 1 to 60 meal structures
  double get previousCyclePendingAmount => allPayments
      .where((p) {
        final status = p['status']?.toString().toLowerCase();
        final isPendingState = status == 'pending' || status == 'processing';
        return isPendingState && _isPreviousCycle(p);
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
          activeSubscriptionId = res['activeSubscriptionId']?.toString();
        });
        _filterData();
      }
    } catch (e) {
      debugPrint("Error fetching payments: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✨ FIXED FILTER MATRIX: Separates and showcases balances dynamically based on choice
  void _filterData() {
    String query = _searchController.text.toLowerCase().trim();

    setState(() {
      filteredPayments = allPayments.where((payment) {
        final student = payment['studentId'] ?? {};
        final name = (student['name'] ?? "").toString().toLowerCase();
        final status = (payment['status'] ?? "").toString().toLowerCase();
        final bool isPrev = _isPreviousCycle(payment);

        // Name / Registration Search parameter match
        final matchesName = name.contains(query);

        // Always show unresolved items, but handle filters gracefully for the paid entries
        bool matchesCycleFilter = false;
        if (selectedFilter == "All") {
          matchesCycleFilter = true; // Shows both old and new pending bills
        } else if (selectedFilter == "Current") {
          matchesCycleFilter = !isPrev; // Only current cycle
        } else if (selectedFilter == "Previous") {
          matchesCycleFilter = isPrev; // Only previous cycle
        }

        return matchesName && matchesCycleFilter;
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
                  "Mess Accounts & Dues Ledger",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.1),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Upper summary section metric cards
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
                
                // ✨ UPDATED ADVANCED CHIP FILTER BAR: Lets managers swap scopes easily
                Row(
                  children: [
                    _buildFilterChip("All Dues", "All"),
                    const SizedBox(width: 6),
                    _buildFilterChip("Current Cycle", "Current"),
                    const SizedBox(width: 6),
                    _buildFilterChip("Previous Cycle", "Previous"),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : filteredPayments.isEmpty
                    ? const Center(
                        child: Text(
                          "No payment entries recorded matching this cycle target.", 
                          style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                          final String cycleDetails = payment['cycleDescription'] ?? "";
                          
                          final bool isPrevCycle = _isPreviousCycle(payment);
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

                          // Component styling mapping matrix
                          Color cardBackground;
                          BorderSide cardBorder;
                          
                          if (isPaid) {
                            cardBackground = Colors.green.withOpacity(0.01);
                            cardBorder = BorderSide(color: Colors.green.withOpacity(0.12));
                          } else if (isPrevCycle) {
                            cardBackground = Colors.red.withOpacity(0.03);
                            cardBorder = BorderSide(color: Colors.red.withOpacity(0.2), width: 1.2);
                          } else {
                            cardBackground = Colors.white;
                            cardBorder = BorderSide(color: Colors.purple.withOpacity(0.15));
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: cardBorder,
                            ),
                            color: cardBackground,
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
                                      content: Text("No verification screenshot uploaded for this bill yet."),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor: isPaid 
                                    ? Colors.green.shade50 
                                    : (isPrevCycle ? Colors.red.shade50 : Colors.orange.shade50),
                                radius: 24,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                                        style: TextStyle(
                                          color: isPaid 
                                              ? Colors.green 
                                              : (isPrevCycle ? Colors.red.shade800 : Colors.orange.shade800),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14.5,
                                        color: isPrevCycle && !isPaid ? Colors.red.shade900 : Colors.black87
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPrevCycle ? Colors.red.withOpacity(0.08) : Colors.purple.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPrevCycle 
                                          ? (recordMonth.isNotEmpty ? "${recordMonth.toUpperCase()} BLOCK" : "PAST BLOCK")
                                          : "ACTIVE BLOCK",
                                      style: TextStyle(
                                        fontSize: 8, 
                                        fontWeight: FontWeight.w900, 
                                        color: isPrevCycle ? Colors.red.shade700 : Colors.purple.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),
                                  Text(
                                    title, 
                                    style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  if (cycleDetails.isNotEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      cycleDetails,
                                      style: TextStyle(color: isPrevCycle ? Colors.red.shade600 : Colors.teal.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate, 
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        isPaid ? Icons.check_circle_rounded : (status == 'processing' ? Icons.hourglass_bottom : Icons.pending_rounded),
                                        size: 13,
                                        color: isPaid ? Colors.green : (isPrevCycle ? Colors.red.shade700 : Colors.orange.shade800),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: isPaid ? Colors.green : (isPrevCycle ? Colors.red.shade800 : Colors.orange.shade800),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Text(
                                "₹$amount",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 15, 
                                  color: isPrevCycle && !isPaid ? Colors.red.shade700 : Colors.black87
                                ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryCard("Current Cycle Paid", currentFinesPaid, Colors.green),
              const SizedBox(width: 8),
              _buildSummaryCard("Current Cycle Due", currentFinesPending, Colors.purple),
            ],
          ),
          const SizedBox(height: 8),
          _buildPreviousMonthSummaryCard("PREVIOUS EXHAUSTED PACKAGES OUTSTANDING DUE", previousCyclePendingAmount),
          const SizedBox(height: 8),
          _buildGlobalTotalSummaryCard("COMBINED TOTAL OUTSTANDING BALANCE", totalOutstandingDebt),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.withOpacity(0.8), letterSpacing: 0.1),
            ),
            const SizedBox(height: 4),
            Text(
              "₹${amount.toStringAsFixed(0)}", 
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousMonthSummaryCard(String label, double amount) {
    final Color cardColor = amount > 0 ? Colors.red : Colors.grey.shade400;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: amount > 0 ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: amount > 0 ? Colors.red.shade900 : Colors.grey.shade700),
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: amount > 0 ? Colors.red.shade700 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalTotalSummaryCard(String label, double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: amount > 0 ? Colors.amber.shade50.withOpacity(0.4) : Colors.teal.shade50.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amount > 0 ? Colors.amber.shade400 : Colors.teal.shade400, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, size: 16, color: amount > 0 ? Colors.amber.shade900 : Colors.teal.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: amount > 0 ? Colors.amber.shade900 : Colors.teal.shade900, letterSpacing: 0.1),
                  ),
                ),
              ],
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: amount > 0 ? Colors.amber.shade900 : Colors.teal.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    bool isSelected = selectedFilter == filterKey;
    
    return InkWell(
      onTap: () {
        setState(() => selectedFilter = filterKey);
        _filterData();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// PaymentScreenshotScreen remains unchanged...
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
                      const SizedBox(height: 16),
                      Text("Failed to load image file", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
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