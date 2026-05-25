import 'package:HostelMess/screens/managerScreen/FineManagementPage/PaymentDetailScreen/PaymentDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class FineManagementPage extends StatefulWidget {
  const FineManagementPage({super.key});

  @override
  State<FineManagementPage> createState() => _FineManagementPageState();
}

class _FineManagementPageState extends State<FineManagementPage> {
  final api = ApiService();
  bool isLoading = false;

  // --- Data State ---
  List<dynamic> allStudents = [];
  List<dynamic> pendingPayments = [];
  String searchQuery = "";
  DateTime _selectedMonth = DateTime.now();
  List<dynamic> monthlyBills = [];

  String selectedBillFilter = 'All';
  String billSearchQuery = "";

  // --- MENU PRICE CONTROLLERS (Single Unit Prices for Fines) ---
  final TextEditingController _vegPriceController = TextEditingController(
    text: "35",
  );
  final TextEditingController _eggPriceController = TextEditingController(
    text: "45",
  );
  final TextEditingController _paneerPriceController = TextEditingController(
    text: "45",
  );
  final TextEditingController _chickenPriceController = TextEditingController(
    text: "65",
  );
  final TextEditingController _fishPriceController = TextEditingController(
    text: "55",
  );
  final TextEditingController _muttonPriceController = TextEditingController(
    text: "85",
  );

  // --- PLAN A CONTROLLERS (1000 Rupee / Basic) ---
  final TextEditingController _planAPrice = TextEditingController(text: "1000");
  final TextEditingController _planAVeg = TextEditingController(text: "16");
  final TextEditingController _planAChicken = TextEditingController(text: "4");
  final TextEditingController _planAFish = TextEditingController(text: "4");
  final TextEditingController _planAEgg = TextEditingController(text: "4");
  final TextEditingController _planAPaneer = TextEditingController(text: "2");
  final TextEditingController _planAMutton = TextEditingController(text: "0");

  // --- PLAN B CONTROLLERS (1500 Rupee / Premium) ---
  final TextEditingController _planBPrice = TextEditingController(text: "1500");
  final TextEditingController _planBVeg = TextEditingController(text: "32");
  final TextEditingController _planBChicken = TextEditingController(text: "8");
  final TextEditingController _planBFish = TextEditingController(text: "8");
  final TextEditingController _planBEgg = TextEditingController(text: "8");
  final TextEditingController _planBPaneer = TextEditingController(text: "4");
  final TextEditingController _planBMutton = TextEditingController(text: "1");

  // --- PLAN C CONTROLLERS (1000 Rupee / Veg) ---
  final TextEditingController _planCPrice = TextEditingController(text: "1000");
  final TextEditingController _planCVeg = TextEditingController(text: "60");
  final TextEditingController _planCChicken = TextEditingController(text: "0");
  final TextEditingController _planCFish = TextEditingController(text: "0");
  final TextEditingController _planCEgg = TextEditingController(text: "0");
  final TextEditingController _planCPaneer = TextEditingController(text: "0");
  final TextEditingController _planCMutton = TextEditingController(text: "0");

  // --- UPI CONTROLLERS ---
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _merchantNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchSavedPrices();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    await Future.wait([_loadBills(), _fetchAllStudents()]);
    if (mounted) setState(() => isLoading = false);
  }

  // --- API LOGIC ---
Future<void> _fetchSavedPrices() async {
    try {
      // The backend returns the map properties directly at the root object level
      final res = await api.getSattingData();
      print("Raw Config Response: $res");
      
      if (res == null) return;

      if (mounted) {
        setState(() {
          // 1. Parse Fine Prices Block
          if (res['finePrices'] != null &&
              res['finePrices']['prices'] != null) {
            final p = res['finePrices']['prices'];
            _vegPriceController.text = p['veg']?.toString() ?? "35";
            _eggPriceController.text = p['egg']?.toString() ?? "45";
            _paneerPriceController.text = p['paneer']?.toString() ?? "45";
            _chickenPriceController.text = p['chicken']?.toString() ?? "65";
            _fishPriceController.text = p['fish']?.toString() ?? "55";
            _muttonPriceController.text = p['mutton']?.toString() ?? "85";
          }

          // 2. Parse UPI Details Block
          if (res['upi'] != null) {
            _upiIdController.text = res['upi']['upiId'] ?? "";
            _merchantNameController.text = res['upi']['merchantName'] ?? "";
          }

          // 3. Parse Meal Subscription Plans Block
          if (res['plans'] != null && res['plans'] is List) {
            for (var plan in res['plans']) {
              final limits = plan['limits'] ?? {};
              final planType = plan['planType']?.toString().toLowerCase() ?? "";

              if (planType == "30 meals") {
                _planAPrice.text = plan['monthlyPrice']?.toString() ?? "1000";
                _planAVeg.text = limits['veg']?.toString() ?? "16";
                _planAChicken.text = limits['chicken']?.toString() ?? "4";
                _planAFish.text = limits['fish']?.toString() ?? "4";
                _planAEgg.text = limits['egg']?.toString() ?? "4";
                _planAPaneer.text = limits['paneer']?.toString() ?? "2";
                _planAMutton.text = limits['mutton']?.toString() ?? "0";
              } else if (planType == "60 meals") {
                _planBPrice.text = plan['monthlyPrice']?.toString() ?? "1500";
                _planBVeg.text = limits['veg']?.toString() ?? "32";
                _planBChicken.text = limits['chicken']?.toString() ?? "8";
                _planBFish.text = limits['fish']?.toString() ?? "8";
                _planBEgg.text = limits['egg']?.toString() ?? "8";
                _planBPaneer.text = limits['paneer']?.toString() ?? "4";
                _planBMutton.text = limits['mutton']?.toString() ?? "1";
              } else if (planType == "60 veg meals") {
                _planCPrice.text = plan['monthlyPrice']?.toString() ?? "1000";
                _planCVeg.text = limits['veg']?.toString() ?? "60";
                _planCChicken.text = limits['chicken']?.toString() ?? "0";
                _planCFish.text = limits['fish']?.toString() ?? "0";
                _planCEgg.text = limits['egg']?.toString() ?? "0";
                _planCPaneer.text = limits['paneer']?.toString() ?? "0";
                _planCMutton.text = limits['mutton']?.toString() ?? "0";
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Setting Load Error: $e");
    }
  }


  Future<void> _saveAllSettings() async {
    setState(() => isLoading = true);

    final Map<String, dynamic> fullConfig = {
      "finePrices": {
        "veg": int.tryParse(_vegPriceController.text) ?? 0,
        "egg": int.tryParse(_eggPriceController.text) ?? 0,
        "paneer": int.tryParse(_paneerPriceController.text) ?? 0,
        "chicken": int.tryParse(_chickenPriceController.text) ?? 0,
        "fish": int.tryParse(_fishPriceController.text) ?? 0,
        "mutton": int.tryParse(_muttonPriceController.text) ?? 0,
      },
      "plans": {
        "basic": {
          "price": int.tryParse(_planAPrice.text) ?? 1000,
          "limits": {
            "veg": int.tryParse(_planAVeg.text) ?? 0,
            "chicken": int.tryParse(_planAChicken.text) ?? 0,
            "fish": int.tryParse(_planAFish.text) ?? 0,
            "egg": int.tryParse(_planAEgg.text) ?? 0,
            "paneer": int.tryParse(_planAPaneer.text) ?? 0,
            "mutton": int.tryParse(_planAMutton.text) ?? 0,
          },
        },
        "premium": {
          "price": int.tryParse(_planBPrice.text) ?? 1500,
          "limits": {
            "veg": int.tryParse(_planBVeg.text) ?? 0,
            "chicken": int.tryParse(_planBChicken.text) ?? 0,
            "fish": int.tryParse(_planBFish.text) ?? 0,
            "egg": int.tryParse(_planBEgg.text) ?? 0,
            "paneer": int.tryParse(_planBPaneer.text) ?? 0,
            "mutton": int.tryParse(_planBMutton.text) ?? 0,
          },
        },
        "veg_60": {
          "price": int.tryParse(_planCPrice.text) ?? 1000,
          "limits": {
            "veg": int.tryParse(_planCVeg.text) ?? 0,
            "chicken": int.tryParse(_planCChicken.text) ?? 0,
            "fish": int.tryParse(_planCFish.text) ?? 0,
            "egg": int.tryParse(_planCEgg.text) ?? 0,
            "paneer": int.tryParse(_planCPaneer.text) ?? 0,
            "mutton": int.tryParse(_planCMutton.text) ?? 0,
          },
        },
      },
      "upi": {
        "upiId": _upiIdController.text.trim(),
        "merchantName": _merchantNameController.text.trim(),
      },
    };

    try {
      final success = await api.saveSettingData(fullConfig);
      if (!mounted) return; // BuildContext Tap Safety Guard Hook
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All Configurations Saved Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save settings"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchAllStudents() async {
    final res = await api.getAllStudents();
    if (mounted) setState(() => allStudents = res ?? []);
  }

  Future<void> _loadBills() async {
    if (mounted) setState(() => isLoading = true);
    String formattedMonth = DateFormat('yyyy-MM').format(_selectedMonth);

    final res = await api.getBillsByMonth(formattedMonth);
    if (mounted) {
      setState(() {
        monthlyBills = res ?? [];
        isLoading = false;
      });
    }
  }

  Future<void> _updateBillStatus(String fineId, String newStatus) async {
    setState(() => isLoading = true);
    try {
      final success = await api.updateFineStatus(fineId, newStatus);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bill marked as $newStatus"),
            backgroundColor: newStatus == 'success'
                ? Colors.green
                : Colors.orange,
          ),
        );
        _loadBills();
      } else {
        throw Exception("Failed");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update status"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteBillConfirmation(String fineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Bill?"),
          ],
        ),
        content: const Text(
          "Are you sure you want to completely delete this bill? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isLoading = true);
              try {
                final success = await api.deleteFine(fineId);
                if (success) {
                  _loadBills();
                }
              } catch (e) {
                if (mounted) setState(() => isLoading = false);
              }
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  void _autoConvertToPlan(Map<String, dynamic> bill) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upgrade, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text("Convert to Meal Plan?"),
          ],
        ),
        content: const Text(
          "This will automatically convert this fine into a full monthly meal subscription for the student.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text("PROCEED"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
    );

    try {
      String studentId = bill['studentId'] is Map
          ? bill['studentId']['_id']
          : bill['studentId'].toString();
      final allSubs = await api.getManagerSubscriptions();
      final existingSub = allSubs.firstWhere((s) {
        String sId = s['studentId'] is Map
            ? s['studentId']['_id']
            : s['studentId'].toString();
        return sId == studentId &&
            (s['status'] == 'active' || s['status'] == 'pending');
      }, orElse: () => null);

      final res = await api.getmealPackages();
      List<dynamic> availablePlans = [];
      if (res != null) {
        availablePlans = res['data'] ?? res['packages'] ?? [];
      }

      if (availablePlans.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }

      String planId =
          (existingSub != null && existingSub['mealsPlanId'] != null)
          ? (existingSub['mealsPlanId'] is Map
                ? existingSub['mealsPlanId']['_id']
                : existingSub['mealsPlanId'].toString())
          : availablePlans[0]['_id'].toString();

      final success = await api.convertFineToSub(bill['_id'], planId);
      if (mounted) Navigator.pop(context);
      if (success) _loadBills();
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _executeGuestConversion(
    String billId,
    StateSetter setParentState,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Confirm Conversion"),
          ],
        ),
        content: const Text(
          "Are you sure you want to proceed? The student's monthly subscription will be permanently cancelled, and these new guest meal bills will be generated.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text("PROCEED"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setParentState(() => isLoading = true);

    final success = await api.convertPackToGuestMeal(billId, {});
    if (mounted) {
      Navigator.pop(context);
      if (success) _loadBills();
    }
  }

  void _showConvertPackToGuestDialog(Map<String, dynamic> bill) async {
    int vUsed = 0, eUsed = 0, pUsed = 0, cUsed = 0, fUsed = 0, mUsed = 0;

    if (bill['subscriptionId'] != null &&
        bill['subscriptionId'] is Map &&
        bill['subscriptionId']['usage'] != null) {
      final usage = bill['subscriptionId']['usage'];
      vUsed = (usage['veg'] as num?)?.toInt() ?? 0;
      eUsed = (usage['egg'] as num?)?.toInt() ?? 0;
      pUsed = (usage['paneer'] as num?)?.toInt() ?? 0;
      cUsed = (usage['chicken'] as num?)?.toInt() ?? 0;
      fUsed = (usage['fish'] as num?)?.toInt() ?? 0;
      mUsed = (usage['mutton'] as num?)?.toInt() ?? 0;
    } else if (bill['subscriptionId'] != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      try {
        String subId = bill['subscriptionId'].toString();
        final allSubs = await api.getManagerSubscriptions();
        final targetSub = allSubs.firstWhere(
          (s) => s['_id'] == subId,
          orElse: () => null,
        );

        if (targetSub != null && targetSub['usage'] != null) {
          final usage = targetSub['usage'];
          vUsed = (usage['veg'] as num?)?.toInt() ?? 0;
          eUsed = (usage['egg'] as num?)?.toInt() ?? 0;
          pUsed = (usage['paneer'] as num?)?.toInt() ?? 0;
          cUsed = (usage['chicken'] as num?)?.toInt() ?? 0;
          fUsed = (usage['fish'] as num?)?.toInt() ?? 0;
          mUsed = (usage['mutton'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        debugPrint("Error fetching subscription usage: $e");
      }
      if (mounted) Navigator.pop(context);
    }

    int vPrice = int.tryParse(_vegPriceController.text) ?? 35;
    int ePrice = int.tryParse(_eggPriceController.text) ?? 45;
    int pPrice = int.tryParse(_paneerPriceController.text) ?? 45;
    int cPrice = int.tryParse(_chickenPriceController.text) ?? 65;
    int fPrice = int.tryParse(_fishPriceController.text) ?? 55;
    int mPrice = int.tryParse(_muttonPriceController.text) ?? 85;

    int totalCost =
        (vUsed * vPrice) +
        (eUsed * ePrice) +
        (pUsed * pPrice) +
        (cUsed * cPrice) +
        (fUsed * fPrice) +
        (mUsed * mPrice);
    int totalMeals = vUsed + eUsed + pUsed + cUsed + fUsed + mUsed;

    List<Map<String, dynamic>> breakdown = [
      {"name": "Veg", "used": vUsed, "price": vPrice, "total": vUsed * vPrice},
      {"name": "Egg", "used": eUsed, "price": ePrice, "total": eUsed * ePrice},
      {
        "name": "Paneer",
        "used": pUsed,
        "price": pPrice,
        "total": pUsed * pPrice,
      },
      {
        "name": "Chicken",
        "used": cUsed,
        "price": cPrice,
        "total": cUsed * cPrice,
      },
      {"name": "Fish", "used": fUsed, "price": fPrice, "total": fUsed * fPrice},
      {
        "name": "Mutton",
        "used": mUsed,
        "price": mPrice,
        "total": mUsed * mPrice,
      },
    ];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.fastfood, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Convert to Guest Meals",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "This will cancel the subscription, delete the package bill, and generate individual bills based on actual consumption.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Total Meals Consumed",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "$totalMeals Plates",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Divider(height: 20),
                        const Text(
                          "Total Fine Amount",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "₹$totalCost",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...breakdown.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${item['name']} (${item['used']} @ ₹${item['price']})",
                            style: TextStyle(
                              fontSize: 13,
                              color: item['used'] > 0
                                  ? Colors.black87
                                  : Colors.grey,
                              fontWeight: item['used'] > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            "₹${item['total']}",
                            style: TextStyle(
                              fontSize: 13,
                              color: item['used'] > 0
                                  ? Colors.redAccent
                                  : Colors.grey,
                              fontWeight: item['used'] > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "CANCEL",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    _executeGuestConversion(bill['_id'], setDialogState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("CREATE FINES"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manager Panel"),
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Bills"),
              Tab(icon: Icon(Icons.people), text: "Students"),
              Tab(icon: Icon(Icons.settings), text: "Settings"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBillsTab(),
            _buildStudentsTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsTab() {
    final now = DateTime.now();
    bool canGoForward =
        _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.redAccent),
                onPressed: () {
                  setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    ),
                  );
                  _loadBills();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: canGoForward ? Colors.redAccent : Colors.grey.shade300,
                ),
                onPressed: canGoForward
                    ? () {
                        setState(
                          () => _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          ),
                        );
                        _loadBills();
                      }
                    : null,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            elevation: 1,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              onChanged: (v) => setState(() => billSearchQuery = v),
              decoration: InputDecoration(
                hintText: "Search bill by name or email...",
                prefixIcon: const Icon(
                  Icons.person_search,
                  color: Colors.redAccent,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        _buildBillFilters(),
        const Divider(height: 1),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                )
              : _buildPaymentList(),
        ),
      ],
    );
  }

  Widget _buildPaymentList() {
    List<dynamic> filteredBills = monthlyBills.where((b) {
      final student = b['studentId'];
      final String name = (student?['name'] ?? "").toString().toLowerCase();
      final String email = (student?['email'] ?? "").toString().toLowerCase();
      final String status = (b['status'] ?? 'pending').toString().toLowerCase();
      final String query = billSearchQuery.toLowerCase().trim();

      bool matchesStatus =
          selectedBillFilter == 'All' ||
          status == selectedBillFilter.toLowerCase();
      bool matchesSearch = name.contains(query) || email.contains(query);
      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredBills.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBills,
        color: Colors.redAccent,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Container(
                height: constraints.maxHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  billSearchQuery.isNotEmpty
                      ? "No records matching '$billSearchQuery' found"
                      : "No $selectedBillFilter bills found",
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      color: Colors.redAccent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: filteredBills.length,
        itemBuilder: (context, index) {
          final p = filteredBills[index];
          final student = p['studentId'];
          final String? photoUrl = student != null ? student['photoURL'] : null;
          final String status = p['status'] ?? 'pending';

          return Card(
            margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                student?['name'] ?? "Unknown Student",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("₹${p['amount']} - ${p['title']}"),
                  if (student?['email'] != null)
                    Text(
                      "${student['email']}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _buildStatusBadge(status),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'approve')
                    _updateBillStatus(p['_id'], 'success');
                  if (value == 'reject')
                    _updateBillStatus(p['_id'], 'rejected');
                  if (value == 'delete') _showDeleteBillConfirmation(p['_id']);
                  if (value == 'convert_to_sub') _autoConvertToPlan(p);
                  if (value == 'convert_to_guest')
                    _showConvertPackToGuestDialog(p);
                },
                itemBuilder: (context) => [
                  if (status.toLowerCase() != 'success' &&
                      status.toLowerCase() != 'approved')
                    const PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text("Approve Payment"),
                        ],
                      ),
                    ),
                  if (status.toLowerCase() != 'rejected')
                    const PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text("Reject Payment"),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text("Delete Bill"),
                      ],
                    ),
                  ),
                  if (p['isMealPackage'] != true)
                    const PopupMenuItem(
                      value: 'convert_to_sub',
                      child: Row(
                        children: [
                          Icon(
                            Icons.upgrade,
                            color: Colors.deepPurple,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text("Convert to Meal Plan"),
                        ],
                      ),
                    ),
                  if (p['isMealPackage'] == true)
                    const PopupMenuItem(
                      value: 'convert_to_guest',
                      child: Row(
                        children: [
                          Icon(Icons.fastfood, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text("Convert to Guest Meals"),
                        ],
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentDetailScreen(payment: p),
                  ),
                ).then((_) => _loadBills());
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillFilters() {
    List<String> statuses = ['All', 'Pending', 'Success', 'Rejected'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((status) {
            bool isSelected = selectedBillFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(status),
                selected: isSelected,
                selectedColor: Colors.redAccent.withOpacity(0.2),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.redAccent : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? Colors.redAccent : Colors.grey.shade300,
                ),
                onSelected: (bool selected) {
                  setState(() => selectedBillFilter = status);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    final filtered = allStudents
        .where(
          (s) => s['name'].toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            elevation: 2,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(15),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search student...",
                prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAllStudents,
            color: Colors.redAccent,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (c, i) {
                final student = filtered[i];
                final String? photoUrl = student['photoURL'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 30,
                            )
                          : null,
                    ),
                    title: Text(
                      student['name'] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      student['email'] ?? "No email provided",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.redAccent,
                        size: 30,
                      ),
                      onPressed: () => _showIndividualFineDialog(student),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPlanLimitsCard(),
        const SizedBox(height: 16),
        _buildPriceMenuCard(),
        const SizedBox(height: 16),
        _buildUpiCard(),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveAllSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
          ),
          child: const Text("SAVE ALL CONFIGURATIONS"),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPlanLimitsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Monthly Included Meals (Limits)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            _planSection(
              "30 MEALS PLAN (₹)",
              _planAPrice,
              _planAVeg,
              _planAChicken,
              _planAFish,
              _planAEgg,
              _planAPaneer,
              _planAMutton,
              Colors.orange,
            ),
            const SizedBox(height: 20),
            _planSection(
              "60 MEALS PLAN (₹)",
              _planBPrice,
              _planBVeg,
              _planBChicken,
              _planBFish,
              _planBEgg,
              _planBPaneer,
              _planBMutton,
              Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            _planSection(
              "60 VEG MEALS PLAN (₹)",
              _planCPrice,
              _planCVeg,
              _planCChicken,
              _planCFish,
              _planCEgg,
              _planCPaneer,
              _planCMutton,
              Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _planSection(
    String name,
    var p,
    var v,
    var c,
    var f,
    var e,
    var pan,
    var mut,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(child: _miniInp("Price", p)),
            Expanded(child: _miniInp("Veg", v)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _miniInp("Chicken", c)),
            Expanded(child: _miniInp("Fish", f)),
            Expanded(child: _miniInp("Egg", e)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _miniInp("Paneer", pan)),
            Expanded(child: _miniInp("Mutton", mut)),
          ],
        ),
      ],
    );
  }

  Widget _miniInp(String l, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildPriceMenuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Extra Meal Fine Rates (Per Plate)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(child: _miniInp("Veg", _vegPriceController)),
                Expanded(child: _miniInp("Egg", _eggPriceController)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _miniInp("Paneer", _paneerPriceController)),
                Expanded(child: _miniInp("Chicken", _chickenPriceController)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _miniInp("Fish", _fishPriceController)),
                Expanded(child: _miniInp("Mutton", _muttonPriceController)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Payment Receiving Info",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _upiIdController,
              decoration: const InputDecoration(labelText: "UPI ID"),
            ),
            TextField(
              controller: _merchantNameController,
              decoration: const InputDecoration(labelText: "Display Name"),
            ),
          ],
        ),
      ),
    );
  }

  void _showIndividualFineDialog(dynamic student) {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _amountController = TextEditingController();
    final TextEditingController _descController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(child: Text("Bill for ${student['name']}")),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Title",
                      hintText: "e.g., Extra Chicken, Damage Fine",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount (₹)",
                      prefixText: "₹ ",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Description (Optional)",
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "CANCEL",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        if (_titleController.text.isEmpty ||
                            _amountController.text.isEmpty)
                          return;
                        setDialogState(() => isCreating = true);

                        final bool success = await api.createIndividualFine({
                          "studentId": student['_id'],
                          "title": _titleController.text.trim(),
                          "amount": int.tryParse(_amountController.text) ?? 0,
                          "description": _descController.text.trim(),
                        });

                        if (mounted) setDialogState(() => isCreating = false);
                        if (success) {
                          Navigator.pop(context);
                          _loadBills();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("GENERATE"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'processing':
        color = Colors.blue;
        break;
      case 'success':
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
}
