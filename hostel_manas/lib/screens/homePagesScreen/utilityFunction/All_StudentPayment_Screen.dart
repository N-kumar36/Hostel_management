import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart'; // Make sure this path is correct

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData);
    _fetchData();
  }

  @override
  void dispose() {
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
    String query = _searchController.text.toLowerCase();

    setState(() {
      filteredPayments = allPayments.where((payment) {
        // Extract nested student object safely
        final student = payment['studentId'] ?? {};
        final name = (student['name'] ?? "").toString().toLowerCase();
        final status = (payment['status'] ?? "").toString().toLowerCase();

        // Check search query
        final matchesName = name.contains(query);

        // Map UI filters to Database Enums ('success', 'pending', 'processing')
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
          // 1. Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // 2. Header & Close Button
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

          // 3. Search Bar & Filters
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

          // 4. Student List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : filteredPayments.isEmpty
                ? const Center(
                    child: Text(
                      "No records found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: filteredPayments.length,
                    itemBuilder: (context, index) {
                      final payment = filteredPayments[index];
                      final student = payment['studentId'] ?? {};

                      final String name = student['name'] ?? "Unknown";
                      final String photoUrl = student['photoURL'] ?? "";
                      final String title = payment['title'] ?? "Payment";
                      final amount = payment['amount'] ?? 0;

                      final String status = (payment['status'] ?? "pending")
                          .toString()
                          .toLowerCase();
                      final bool isPaid = status == 'success';

                      // Format the ISO Date
                      String formattedDate = "N/A";
                      if (payment['date'] != null) {
                        try {
                          DateTime date = DateTime.parse(
                            payment['date'],
                          ).toLocal();
                          formattedDate = DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(date);
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isPaid
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            radius: 24,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      color: isPaid
                                          ? Colors.green
                                          : Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                title, // E.g. "Mess Bill - 30 meals"
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate, // E.g. "01 Apr 2026, 01:28 PM"
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    isPaid ? Icons.check_circle : Icons.pending,
                                    size: 14,
                                    color: isPaid
                                        ? Colors.green
                                        : Colors.orange.shade800,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPaid ? "Paid" : "Pending",
                                    style: TextStyle(
                                      color: isPaid
                                          ? Colors.green
                                          : Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Text(
                            "₹$amount",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
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
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade300,
          ),
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
