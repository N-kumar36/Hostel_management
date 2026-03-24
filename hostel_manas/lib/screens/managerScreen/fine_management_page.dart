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
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

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
    await Future.wait([_loadPendingFines(), _fetchAllStudents()]);
    setState(() => isLoading = false);
  }

  // --- API LOGIC ---
  Future<void> _fetchSavedPrices() async {
    try {
      final res = await api.getSattingData();
      if (res != null) {
        setState(() {
          // 1. Map Fine Prices
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

          // 2. Map UPI Details
          if (res['upi'] != null) {
            _upiIdController.text = res['upi']['upiId'] ?? "";
            _merchantNameController.text = res['upi']['merchantName'] ?? "";
          }

          // 3. Map Plan Limits (Iterating through the list)
          if (res['plans'] != null && res['plans'] is List) {
            for (var plan in res['plans']) {
              final limits = plan['limits'];
              if (plan['monthlyPrice'] == 1000) {
                _planAVeg.text = limits['veg']?.toString() ?? "16";
                _planAChicken.text = limits['chicken']?.toString() ?? "4";
                _planAFish.text = limits['fish']?.toString() ?? "4";
                _planAEgg.text = limits['egg']?.toString() ?? "4";
                _planAPaneer.text = limits['paneer']?.toString() ?? "2";
                _planAMutton.text = limits['mutton']?.toString() ?? "0";
              } else if (plan['monthlyPrice'] == 1500) {
                _planBVeg.text = limits['veg']?.toString() ?? "32";
                _planBChicken.text = limits['chicken']?.toString() ?? "8";
                _planBFish.text = limits['fish']?.toString() ?? "8";
                _planBEgg.text = limits['egg']?.toString() ?? "8";
                _planBPaneer.text = limits['paneer']?.toString() ?? "4";
                _planBMutton.text = limits['mutton']?.toString() ?? "1";
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

    // Construct the full configuration object
    final Map<String, dynamic> fullConfig = {
      // 1. Individual Fine Prices (for the 'prices' collection/document)
      "finePrices": {
        "veg": int.tryParse(_vegPriceController.text) ?? 0,
        "egg": int.tryParse(_eggPriceController.text) ?? 0,
        "paneer": int.tryParse(_paneerPriceController.text) ?? 0,
        "chicken": int.tryParse(_chickenPriceController.text) ?? 0,
        "fish": int.tryParse(_fishPriceController.text) ?? 0,
        "mutton": int.tryParse(_muttonPriceController.text) ?? 0,
      },

      // 2. Monthly Plan Limits (for the 'plans' collection)
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
      },

      // 3. Manager UPI Details (for the 'hostel_details' or 'upi' collection)
      "upi": {
        "upiId": _upiIdController.text.trim(),
        "merchantName": _merchantNameController.text.trim(),
      },
    };

    try {
      // Single API call to save everything
      final success = await api.saveSettingData(fullConfig);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All Configurations Saved Successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save settings"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _generateBulkFees() async {
    bool confirm = await _showConfirmDialog(
      "Confirm Calculation",
      "This will generate fines for $selectedMonth based on consumption vs plan limits.",
    );
    if (!confirm) return;

    setState(() => isLoading = true);
    try {
      await api.generateBulkFines({"month": selectedMonth});
      _loadPendingFines();
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchAllStudents() async {
    final res = await api.getAllStudents();
    setState(() => allStudents = res ?? []);
  }

  Future<void> _loadPendingFines() async {
    final res = await api.getPendingFines();
    setState(() => pendingPayments = res ?? []);
  }

  // --- UI TABS ---

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGenerationCard(),
        const SizedBox(height: 20),
        const Text(
          "PENDING VERIFICATIONS",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else
          _buildPaymentList(),
      ],
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
            elevation: 2, // Move elevation here
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(15),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search student...",
                prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                filled: true,
                fillColor: Colors.white,
                // Remove border side to keep it clean with the Material shadow
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (c, i) {
              final student = filtered[i];
              final String? photoUrl =
                  student['photoURL']; // Make sure key matches your User model

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
                        ? const Icon(Icons.person, color: Colors.grey, size: 30)
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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

  // --- SUB-WIDGETS ---

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
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
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

  Widget _buildGenerationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent, Colors.orangeAccent],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            "GENERATE BILLS FOR $selectedMonth",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _generateBulkFees,
            child: const Text("RUN CALCULATION"),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    if (pendingPayments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("No pending verifications"),
        ),
      );
    }
    return Column(
      children: pendingPayments.map((p) {
        final student = p['studentId'];
        final String? photoUrl = student != null ? student['photoURL'] : null;

        return Card(
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
              student?['name'] ?? "Unknown",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("₹${p['amount']} - ${p['title']}"),
            trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentDetailScreen(payment: p),
                ),
              ).then((_) => _loadPendingFines());
            },
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _showConfirmDialog(String t, String d) async {
    return await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(t),
            content: Text(d),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text("PROCEED"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showIndividualFineDialog(dynamic student) {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _amountController = TextEditingController();
    final TextEditingController _descController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // To manage loading state inside dialog
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
                            _amountController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill Title and Amount"),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isCreating = true);

                        final bool success = await api.createIndividualFine({
                          "studentId": student['_id'],
                          "title": _titleController.text.trim(),
                          "amount": int.tryParse(_amountController.text) ?? 0,
                          "description": _descController.text.trim(),
                        });

                        setDialogState(() => isCreating = false);

                        if (success) {
                          Navigator.pop(context);
                          _loadPendingFines(); // Refresh the list on the first tab
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Fine created successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Failed to create fine"),
                              backgroundColor: Colors.red,
                            ),
                          );
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
}
