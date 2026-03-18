import 'package:HostelMess/screens/main_screens/my_meals_page/ConsumptionOverview.dart';
import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import 'package:HostelMess/screens/homePagesScreen/financials_page.dart';
import 'package:intl/intl.dart';

class MyVotesPage extends StatefulWidget {
  const MyVotesPage({super.key});

  @override
  State<MyVotesPage> createState() => _MyVotesPageState();
}

class _MyVotesPageState extends State<MyVotesPage> {
  final api = ApiService();
  final L_S = LocalService();

  List<dynamic> guestRequests = []; // Add this variable to your State class

  int totalMeals = 0;
  int consumedMeals = 0;
  int remainingMeals = 0;
  double pendingDues = 0.0;
  bool isLoading = true;
  List<String> availableDates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await L_S.fetchAndCalculateMealStats();
      final fines = await api.getMyFines();
      final requests = await api.getMyGuestMealRequests();

      final List<String> dates = [
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
        DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now().add(const Duration(days: 1))),
      ];

      double dues = 0.0;
      if (fines != null) {
        for (var f in fines) {
          if (f['status'] == 'pending') {
            dues += double.tryParse(f['amount'].toString()) ?? 0.0;
          }
        }
      }

      if (mounted) {
        setState(() {
          totalMeals = stats['total'] ?? 0;
          consumedMeals = stats['consumed'] ?? 0;
          remainingMeals = totalMeals - consumedMeals;
          pendingDues = dues;
          availableDates = dates;
          guestRequests = requests;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading activity data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Meal & Activity"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.deepPurple,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _sectionHeader("Consumption Overview"),
                  const SizedBox(height: 12),
                  _buildMealStats(),

                  const SizedBox(height: 24),
                  _sectionHeader("Quick Actions"),
                  const SizedBox(height: 12),
                  pendingDues > 0
                      ? _buildBlockedGuestAction()
                      : _buildGuestMealAction(),

                  const SizedBox(height: 24),
                  _sectionHeader("Financial Summary"),
                  const SizedBox(height: 12),
                  _buildPaymentDashboard(),

                  const SizedBox(height: 12),

                  // Inside your ListView children:
                  const SizedBox(height: 24),
                  _sectionHeader("Guest Meal Status"),
                  const SizedBox(height: 12),
                  guestRequests.isEmpty
                      ? _buildEmptyStatus()
                      : Column(
                          children: guestRequests
                              .map((req) => _buildStatusCard(req))
                              .toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMealStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("TOTAL", "$totalMeals", Colors.white, () {
            print("Click Toral ");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ConsumptionOverviewPage(title: "TOTAL MEALS PAGE", Type: 'total',),
              ),
            );
          }),
          Container(width: 1, height: 40, color: Colors.white24),
          _statItem("USED", "$consumedMeals", Colors.white, () {
            print("Click the call back Used");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ConsumptionOverviewPage(title: "USED MEALS PAGE", Type: 'used',),
              ),
            );
          }),
          Container(width: 1, height: 40, color: Colors.white24),
          _statItem("LEFT", "$remainingMeals", Colors.orangeAccent, () {
            print("Click the call back Left");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ConsumptionOverviewPage(title: "TOTAL MEALS LEFT", Type: 'left',),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statItem(
    String label,
    String value,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4), // Small spacing
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDashboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: pendingDues > 0
                ? Colors.red.shade50
                : Colors.green.shade50,
            child: Icon(
              pendingDues > 0 ? Icons.account_balance_wallet : Icons.verified,
              color: pendingDues > 0 ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Pending Fines",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "₹${pendingDues.toInt()}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FinancialsPage()),
              ).then((_) => _loadData());
            },
            child: const Text(
              "HISTORY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestMealAction() {
    return ElevatedButton.icon(
      onPressed: _showGuestMealBottomSheet,
      icon: const Icon(Icons.group_add, size: 20),
      label: const Text(
        "REQUEST GUEST MEAL",
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }

  Widget _buildBlockedGuestAction() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FinancialsPage()),
        ).then((_) => _loadData());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock_outlined, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Guest Request Locked (₹${pendingDues.toInt()})",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    "Clear pending dues to enable guest requests.",
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.red),
          ],
        ),
      ),
    );
  }

  void _showGuestMealBottomSheet() {
    String selectedDate = availableDates.isNotEmpty
        ? availableDates.first
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    String selectedTime = "Night";
    int guestCount = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Request Guest Meal",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select details to notify the mess manager.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),

              const Text(
                "SELECT DATE",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              DropdownButton<String>(
                isExpanded: true,
                underline: Container(
                  height: 1,
                  color: Colors.deepPurple.shade100,
                ),
                value: selectedDate,
                items: availableDates
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedDate = val!),
              ),

              const SizedBox(height: 24),
              const Text(
                "MEAL TIME",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _choiceChip(
                    "Morning",
                    selectedTime == "Morning",
                    (s) => setModalState(() => selectedTime = "Morning"),
                  ),
                  const SizedBox(width: 12),
                  _choiceChip(
                    "Night",
                    selectedTime == "Night",
                    (s) => setModalState(() => selectedTime = "Night"),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                "GUEST COUNT",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => guestCount > 1
                        ? setModalState(() => guestCount--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "$guestCount",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setModalState(() => guestCount++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    // Show a loading indicator if needed
                    final result = await api.requestGuestMeal(
                      guestCount: guestCount,
                      mealDate: selectedDate,
                      mealTime: selectedTime,
                    );

                    if (!mounted) return;
                    Navigator.pop(context); // Close bottom sheet

                    if (result['success']) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                          content: Text("Success: ${result['message']}"),
                        ),
                      );
                      _loadData(); // Refresh page stats
                    } else {
                      // Show error message (e.g., if blocked by fines)
                      _showErrorDialog(result['message']);
                    }
                  },
                  child: const Text(
                    "CONFIRM REQUEST",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String label, bool isSelected, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // Helper to show the error alert
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Denied"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> request) {
    Color statusColor;
    IconData statusIcon;
    bool isPending = request['status'] == 'pending';

    switch (request['status']) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.highlight_off;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        // Changed to Column to add the cancel button below if needed
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${request['guestCount']} Guest(s) - ${request['mealTime']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Date: ${request['mealDate']}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request['status'].toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),

          // Show Cancel button only if status is pending
          if (isPending) ...[
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _confirmCancellation(request['_id']),
                icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                label: const Text(
                  "CANCEL REQUEST",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Show a dialog to confirm the student wants to cancel
  void _confirmCancellation(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Request?"),
        content: const Text(
          "Are you sure you want to cancel this guest meal request?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("NO"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleCancelAction(requestId);
            },
            child: const Text(
              "YES, CANCEL",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Call the API to cancel
  Future<void> _handleCancelAction(String requestId) async {
    setState(() => isLoading = true);
    try {
      // You need to add cancelGuestMealRequest to your ApiService first
      final result = await api.cancelGuestMealRequest(requestId);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request cancelled successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Cancel error: $e");
    } finally {
      _loadData(); // Refresh the UI
    }
  }

  Widget _buildEmptyStatus() {
    return Text(
      "No active guest meal requests.",
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
