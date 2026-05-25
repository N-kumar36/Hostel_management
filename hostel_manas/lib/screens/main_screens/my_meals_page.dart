import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import 'package:HostelMess/screens/homePagesScreen/financials_page.dart';
import './utility_screen/meal_packages_section.dart';
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
  List<String> availableDates = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        api.getVoteSummary(),
        api.getMyFines(),
        api.getMyGuestMealRequests(),
      ]);

      final subResponse = results[0] as Map<String, dynamic>;
      final fines = results[1] as List<dynamic>?;
      final requests = results[2] as List<dynamic>;

      double dues = 0.0;
      if (fines != null) {
        for (var f in fines) {
          final status = f['status']?.toString().toLowerCase();
          if (status == 'pending' || status == 'rejected') {
            dues += double.tryParse(f['amount'].toString()) ?? 0.0;
          }
        }
      }

      if (mounted) {
        setState(() {
          if (subResponse['success'] == true &&
              subResponse['data'] != null &&
              (subResponse['data'] as List).isNotEmpty) {
            final List<dynamic> allSubs = subResponse['data'];

            activeSubscription = allSubs.firstWhere(
              (s) => s['status'] != "completed",
              orElse: () => allSubs[0],
            );

            activePackageId = activeSubscription!['mealsPlanId']?.toString();

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
            totalUsed = 0;
            totalLimit = 0;
            chickenUsed = chickenMax = fishUsed = fishMax = paneerUsed =
                paneerMax = 0;
            muttonUsed = muttonMax = eggUsed = eggMax = vegUsed = vegMax = 0;
          }

          pendingDues = dues;
          guestRequests = requests;

          // Generate formal standard string formats: "DD/MM/YYYY" to check database documents easily
          availableDates = [
            DateFormat('dd/MM/yyyy').format(DateTime.now()),
            DateFormat(
              'dd/MM/yyyy',
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

  IconData _getVariationIcon(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken")) return Icons.kebab_dining_rounded;
    if (c.contains("egg")) return Icons.egg_rounded;
    if (c.contains("fish")) return Icons.set_meal_rounded;
    if (c.contains("veg")) return Icons.grass_rounded;
    return Icons.restaurant_rounded;
  }

  Color _getVariationColor(String choice) {
    final c = choice.toLowerCase();
    if (c.contains("chicken")) return Colors.red.shade700;
    if (c.contains("egg")) return Colors.amber.shade800;
    if (c.contains("fish")) return Colors.blue.shade700;
    if (c.contains("veg")) return Colors.green.shade700;
    return Colors.deepPurple;
  }

  // ✨ NEW CORE FUNCTION: Checks live meal base routine configurations before showing form selectors
  void _showGuestMealBottomSheet() {
    String selectedDateStr = availableDates.isNotEmpty
        ? availableDates.first
        : "";
    String selectedTimeStr = "Morning";
    String guestItemPreference = "regular";
    int guestCount = 1;

    // Local modal internal checking states variables
    bool isCheckingMeal = false;
    bool isMealAvailable = false;
    String detectedMenuName = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Helper internal function to call verification endpoint pipeline on date/time toggle shifts
          Future<void> checkTargetMealRoutine() async {
            setModalState(() {
              isCheckingMeal = true;
              isMealAvailable = false;
            });

            try {
              // Re-use your detailed route map parameters tool safely
              final response = await api.getDetailedVotesByDate(
                selectedDateStr,
                selectedTimeStr,
              );

              setModalState(() {
                isCheckingMeal = false;
                // If response succeeds or contains data rows arrays payload, meal is explicitly active
                if (response['success'] == true || (response['data'] != null)) {
                  isMealAvailable = true;
                  if (response['data'] != null &&
                      (response['data'] as List).isNotEmpty) {
                    detectedMenuName =
                        response['data'][0]['menuItem']
                            ?.toString()
                            .toUpperCase() ??
                        "MEAL";
                  } else {
                    detectedMenuName = "CONFIGURED ROUTINE";
                  }
                } else {
                  isMealAvailable = false;
                }
              });
            } catch (e) {
              setModalState(() {
                isCheckingMeal = false;
                isMealAvailable =
                    false; // Evaluates false if 404 block thrown from ApiService catch block
              });
            }
          }

          // Initial auto trigger on open load window thread execution
          if (!isCheckingMeal && !isMealAvailable && detectedMenuName.isEmpty) {
            checkTargetMealRoutine();
          }

          return Padding(
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
                  value: selectedDateStr.isNotEmpty ? selectedDateStr : null,
                  items: availableDates
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() => selectedDateStr = v);
                      checkTargetMealRoutine();
                    }
                  },
                ),
                const SizedBox(height: 20),

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
                    ChoiceChip(
                      label: const Text("Morning"),
                      selected: selectedTimeStr == "Morning",
                      selectedColor: Colors.deepPurple.shade100,
                      onSelected: (_) {
                        setModalState(() => selectedTimeStr = "Morning");
                        checkTargetMealRoutine();
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text("Night"),
                      selected: selectedTimeStr == "Night",
                      selectedColor: Colors.deepPurple.shade100,
                      onSelected: (_) {
                        setModalState(() => selectedTimeStr = "Night");
                        checkTargetMealRoutine();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 🌟 CONDITION BLOCK: Evaluate checking status loops seamlessly
                if (isCheckingMeal) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.deepPurple,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Checking meal schedule availability...",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isMealAvailable) ...[
                  // ✨ SHOW THIS SCREEN BLOCK IF MANAGER HAS NOT CREATED MEAL ROUTINE IN THIS DATE SLOT
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.no_food_rounded,
                          color: Colors.red.shade700,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "NO MEAL AVAILABLE FOR THIS DATE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "The mess manager has not created or enabled a meal schedule routine for $selectedTimeStr slot on $selectedDateStr yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // IF MEAL ACCORDING TO DATE AND TIME SLOT EXISTS -> SHOW FORM VARIATIONS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Menu Base item Detected: ",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          detectedMenuName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "GUEST MEAL VARIATION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: guestItemPreference,
                    items: const [
                      DropdownMenuItem(
                        value: "regular",
                        child: Text("Regular (Follows Routine Menu)"),
                      ),
                      DropdownMenuItem(
                        value: "halal_chicken",
                        child: Text("Halal Chicken Package"),
                      ),
                      DropdownMenuItem(
                        value: "egg_substitute",
                        child: Text("Egg Substitute alternative"),
                      ),
                      DropdownMenuItem(
                        value: "veg_forced",
                        child: Text("Forced Vegetarian Alternative"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null)
                        setModalState(() => guestItemPreference = v);
                    },
                  ),
                  const SizedBox(height: 20),
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
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMealAvailable
                          ? Colors.deepPurple
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Disable interaction completely if target check fails
                    onPressed: (!isMealAvailable || isCheckingMeal)
                        ? null
                        : () async {
                            final res = await api.requestGuestMeal(
                              guestCount: guestCount,
                              mealDate: selectedDateStr,
                              mealTime: selectedTimeStr,
                              guestItemPreference: guestItemPreference,
                            );
                            if (mounted) Navigator.pop(context);
                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Guest Request Sent Successfully!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadAllData();
                            } else {
                              _showErrorDialog(
                                res['message'] ?? "Request failed",
                              );
                            }
                          },
                    child: const Text(
                      "CONFIRM REQUEST",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
              color: Colors.deepPurple,
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
                  MealPackagesSection(
                    onActionSuccess: () {
                      _loadAllData();
                    },
                  ),
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

  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    ),
  );

  Widget _buildEmptyStatus() => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text(
        "No requests found",
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ),
  );

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
      case 'success':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGuestRequestsList() {
    return Column(
      children: guestRequests.map((req) {
        final String pref = req['guestItemPreference']?.toString() ?? "regular";
        final Color choiceColor = _getVariationColor(pref);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            title: Text(
              "${req['guestCount']} Guests - ${req['mealTime']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  req['mealDate'] ?? "",
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getVariationIcon(pref), size: 12, color: choiceColor),
                    const SizedBox(width: 4),
                    Text(
                      pref.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: choiceColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildStatusBadge(req['status'] ?? 'pending'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: _showGuestMealBottomSheet,
    child: const Text(
      "REQUEST GUEST MEAL",
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildBlockedGuestAction() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade100),
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
