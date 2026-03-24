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

  // --- State Variables ---
  List<dynamic> guestRequests = [];
  List<dynamic> availablePackages = [];
  Map<String, dynamic>? activeSubscription;
  String? activePackageId;

  // --- Consumption Tracking ---
  int chickenUsed = 0, chickenMax = 0;
  int fishUsed = 0, fishMax = 0;
  int paneerUsed = 0, paneerMax = 0;
  int muttonUsed = 0, muttonMax = 0;
  int eggUsed = 0, eggMax = 0;
  int vegUsed = 0, vegMax = 0;
  int totalUsed = 0;
  int totalLimit = 0;

  double pendingDues = 0.0;
  bool isLoading = true;
  bool isPackageUpdating = false;
  List<String> availableDates = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  /// Master Data Loader: Fetches all data and handles multiple subscription logic
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        api.getVoteSummary(), // StudentSubscription
        api.getMyFines(), // Fines/Dues
        api.getMyGuestMealRequests(),
        api.getmealPackages(), // Global Plans
      ]);

      final subResponse = results[0] as Map<String, dynamic>;
      final fines = results[1] as List<dynamic>?;
      final requests = results[2] as List<dynamic>;
      final packageResponse = results[3] as Map<String, dynamic>;

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
          // --- FIX: Logic to handle multiple subscriptions (Completed vs Active) ---
          if (subResponse['success'] == true &&
              (subResponse['data'] as List).isNotEmpty) {
            final List<dynamic> allSubs = subResponse['data'];

            // Preference: 1. Active/Pending, 2. Else Completed
            activeSubscription = allSubs.firstWhere(
              (s) => s['status'] != "completed",
              orElse: () => allSubs[0],
            );

            activePackageId = activeSubscription!['mealsPlanId'];

            final usage = activeSubscription!['usage'] ?? {};
            final limits = activeSubscription!['maxLimits'] ?? {};

            chickenUsed = (usage['chicken'] ?? 0).toInt();
            chickenMax = (limits['chicken'] ?? 0).toInt();
            fishUsed = (usage['fish'] ?? 0).toInt();
            fishMax = (limits['fish'] ?? 0).toInt();
            paneerUsed = (usage['paneer'] ?? 0).toInt();
            paneerMax = (limits['paneer'] ?? 0).toInt();
            muttonUsed = (usage['mutton'] ?? 0).toInt();
            muttonMax = (limits['mutton'] ?? 0).toInt();
            eggUsed = (usage['egg'] ?? 0).toInt();
            eggMax = (limits['egg'] ?? 0).toInt();
            vegUsed = (usage['veg'] ?? 0).toInt();
            vegMax = (limits['veg'] ?? 0).toInt();

            totalUsed =
                chickenUsed +
                fishUsed +
                paneerUsed +
                muttonUsed +
                eggUsed +
                vegUsed;
            totalLimit =
                chickenMax + fishMax + paneerMax + muttonMax + eggMax + vegMax;
          } else {
            activeSubscription = null;
            activePackageId = null;
          }

          availablePackages = packageResponse['data'] ?? [];
          pendingDues = dues;
          guestRequests = requests;
          availableDates = [
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
            DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.now().add(const Duration(days: 1))),
          ];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Master Load Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handlePackageSelection(String packageId) async {
    setState(() => isPackageUpdating = true);
    try {
      final result = await api.selectPackage(packageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Processed!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPackageUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Meal & Activity",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _sectionHeader("Consumption Overview"),
                  const SizedBox(height: 12),
                  _buildMainStatsCard(),
                  const SizedBox(height: 12),
                  _buildDetailedUsageGrid(),

                  const SizedBox(height: 24),
                  _buildMealSubscriptionSection(),

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

                  const SizedBox(height: 24),
                  _sectionHeader("Guest Meal Status"),
                  const SizedBox(height: 12),
                  guestRequests.isEmpty
                      ? _buildEmptyStatus()
                      : _buildGuestRequestsList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildMealSubscriptionSection() {
    if (activeSubscription == null ||
        activeSubscription!['status'] == "completed") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Select Meal Package"),
          const SizedBox(height: 12),
          _buildMealPackageList(),
        ],
      );
    }

    final String planType = activeSubscription!['planType'] ?? "";

    if (planType == "60 meals") {
      return const SizedBox.shrink();
    } else if (planType == "30 meals") {
      return _buildUpgradeBanner();
    }

    return const SizedBox.shrink();
  }

  Widget _buildUpgradeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.white, size: 35),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "UPGRADE AVAILABLE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Unlock 60 meals for ₹500 more",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepOrange,
            ),
            onPressed: isPackageUpdating
                ? null
                : () {
                    final sixtyDay = availablePackages.firstWhere(
                      (p) => p['planType'] == "60 meals",
                      orElse: () => null,
                    );
                    if (sixtyDay != null)
                      _handlePackageSelection(sixtyDay['_id']);
                  },
            child: const Text("PAY ₹500"),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade800],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItemHeader("TOTAL", "$totalLimit", Colors.white),
          _statItemHeader("USED", "$totalUsed", Colors.greenAccent),
          _statItemHeader(
            "LEFT",
            "${totalLimit - totalUsed}",
            Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _statItemHeader(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedUsageGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _gridItem("Chicken", chickenUsed, chickenMax),
              _gridItem("Fish", fishUsed, fishMax),
              _gridItem("Paneer", paneerUsed, paneerMax),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _gridItem("Mutton", muttonUsed, muttonMax),
              _gridItem("Egg", eggUsed, eggMax),
              _gridItem("Veg", vegUsed, vegMax),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridItem(String label, int used, int max) {
    return Column(
      children: [
        Text(
          "$used / $max",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMealPackageList() {
    return Column(
      children: availablePackages
          .map(
            (pkg) => _buildOptionCard(
              id: pkg['_id'],
              title: pkg['planType'],
              price: pkg['monthlyPrice'],
            ),
          )
          .toList(),
    );
  }

  Widget _buildOptionCard({
    required String id,
    required String title,
    required int price,
  }) {
    return GestureDetector(
      onTap: isPackageUpdating ? null : () => _handlePackageSelection(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "₹$price",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
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
          Icon(
            pendingDues > 0 ? Icons.warning : Icons.check_circle,
            color: pendingDues > 0 ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Dues: ₹${pendingDues.toInt()}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FinancialsPage()),
            ).then((_) => _loadAllData()),
            child: const Text("VIEW"),
          ),
        ],
      ),
    );
  }

  // --- GUEST MEAL BOTTOM SHEET ---

  void _showGuestMealBottomSheet() {
    String selectedDate = availableDates.first;
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
              const Divider(height: 32),
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
                value: selectedDate,
                items: availableDates
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setModalState(() => selectedDate = v!),
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
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Morning"),
                    selected: selectedTime == "Morning",
                    onSelected: (_) =>
                        setModalState(() => selectedTime = "Morning"),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text("Night"),
                    selected: selectedTime == "Night",
                    onSelected: (_) =>
                        setModalState(() => selectedTime = "Night"),
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
                  Text(
                    "$guestCount",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                  ),
                  onPressed: () async {
                    final res = await api.requestGuestMeal(
                      guestCount: guestCount,
                      mealDate: selectedDate,
                      mealTime: selectedTime,
                    );
                    Navigator.pop(context);
                    if (res['success']) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Request Sent"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadAllData();
                    } else {
                      _showErrorDialog(res['message']);
                    }
                  },
                  child: const Text("CONFIRM REQUEST"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  // --- HELPERS ---
  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    ),
  );
  Widget _buildEmptyStatus() => const Center(
    child: Text(
      "No requests",
      style: TextStyle(fontSize: 12, color: Colors.grey),
    ),
  );
  Widget _buildGuestRequestsList() {
    return Column(
      children: guestRequests.map((req) {
        Color statusColor = req['status'] == 'approved'
            ? Colors.green
            : (req['status'] == 'rejected' ? Colors.red : Colors.orange);
        return Card(
          child: ListTile(
            title: Text("${req['guestCount']} Guests - ${req['mealTime']}"),
            subtitle: Text(req['mealDate']),
            trailing: Text(
              req['status'].toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuestMealAction() => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
    ),
    onPressed: _showGuestMealBottomSheet,
    child: const Text("REQUEST GUEST MEAL"),
  );
  Widget _buildBlockedGuestAction() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.lock, color: Colors.red),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            "Guest Requests Locked. Clear pending dues.",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
