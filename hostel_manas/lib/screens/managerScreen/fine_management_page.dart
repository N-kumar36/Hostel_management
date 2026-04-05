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

  // --- MENU PRICE CONTROLLERS (Single Unit Prices for Fines) ---
  final TextEditingController _vegPriceController = TextEditingController(text: "35");
  final TextEditingController _eggPriceController = TextEditingController(text: "45");
  final TextEditingController _paneerPriceController = TextEditingController(text: "45");
  final TextEditingController _chickenPriceController = TextEditingController(text: "65");
  final TextEditingController _fishPriceController = TextEditingController(text: "55");
  final TextEditingController _muttonPriceController = TextEditingController(text: "85");

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
    await Future.wait([_loadBills(), _fetchAllStudents()]);
    setState(() => isLoading = false);
  }

  // --- API LOGIC ---
  Future<void> _fetchSavedPrices() async {
    try {
      final res = await api.getSattingData();
      if (res != null) {
        setState(() {
          if (res['finePrices'] != null && res['finePrices']['prices'] != null) {
            final p = res['finePrices']['prices'];
            _vegPriceController.text = p['veg']?.toString() ?? "35";
            _eggPriceController.text = p['egg']?.toString() ?? "45";
            _paneerPriceController.text = p['paneer']?.toString() ?? "45";
            _chickenPriceController.text = p['chicken']?.toString() ?? "65";
            _fishPriceController.text = p['fish']?.toString() ?? "55";
            _muttonPriceController.text = p['mutton']?.toString() ?? "85";
          }

          if (res['upi'] != null) {
            _upiIdController.text = res['upi']['upiId'] ?? "";
            _merchantNameController.text = res['upi']['merchantName'] ?? "";
          }

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
      },
      "upi": {
        "upiId": _upiIdController.text.trim(),
        "merchantName": _merchantNameController.text.trim(),
      },
    };

    try {
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

  Future<void> _fetchAllStudents() async {
    final res = await api.getAllStudents();
    setState(() => allStudents = res ?? []);
  }

  Future<void> _loadBills() async {
    setState(() => isLoading = true);
    
    // NOTE: If your backend expects "March 2026", change this to DateFormat('MMMM yyyy'). 
    // Currently using 'yyyy-MM' as per your previous setup.
    String formattedMonth = DateFormat('yyyy-MM').format(_selectedMonth);
    
    final res = await api.getBillsByMonth(formattedMonth);
    setState(() {
      monthlyBills = res ?? [];
      isLoading = false;
    });
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
    // ✨ FIXED: Check if we are allowed to go to the next month
    final now = DateTime.now();
    bool canGoForward = _selectedMonth.year < now.year || 
                       (_selectedMonth.year == now.year && _selectedMonth.month < now.month);

    return Column(
      children: [
        // --- MONTH SELECTOR UI ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                  _loadBills();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // ✨ FIXED: Disables the button and grays it out if trying to go past current month
              IconButton(
                icon: Icon(
                  Icons.chevron_right, 
                  color: canGoForward ? Colors.redAccent : Colors.grey.shade300,
                ),
                onPressed: canGoForward
                    ? () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        });
                        _loadBills();
                      }
                    : null, // Null disables the button entirely
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // --- BILLS LIST WITH REFRESH ---
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : _buildPaymentList(),
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    final filtered = allStudents
        .where((s) => s['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()))
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
        // ✨ FIXED: Added RefreshIndicator so managers can pull to refresh the student list!
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAllStudents,
            color: Colors.redAccent,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // Ensures it can be pulled even if list is short
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (c, i) {
                final student = filtered[i];
                final String? photoUrl = student['photoURL'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                      child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.grey, size: 30) : null,
                    ),
                    title: Text(student['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(student['email'] ?? "No email provided", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.redAccent, size: 30),
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

  // --- SUB-WIDGETS ---
  Widget _buildPlanLimitsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Monthly Included Meals (Limits)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _planSection("30 MEALS PLAN (₹)", _planAPrice, _planAVeg, _planAChicken, _planAFish, _planAEgg, _planAPaneer, _planAMutton, Colors.orange),
            const SizedBox(height: 20),
            _planSection("60 MEALS PLAN (₹)", _planBPrice, _planBVeg, _planBChicken, _planBFish, _planBEgg, _planBPaneer, _planBMutton, Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _planSection(String name, var p, var v, var c, var f, var e, var pan, var mut, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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
            const Text("Extra Meal Fine Rates (Per Plate)", style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text("Payment Receiving Info", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _upiIdController, decoration: const InputDecoration(labelText: "UPI ID")),
            TextField(controller: _merchantNameController, decoration: const InputDecoration(labelText: "Display Name")),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending': color = Colors.orange; break;
      case 'processing': color = Colors.blue; break;
      case 'success': case 'approved': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      default: color = Colors.grey;
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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- Updated List Widget With PULL-TO-REFRESH ---
  Widget _buildPaymentList() {
    // If empty, return a Scrollable area inside the RefreshIndicator so it can still be pulled!
    if (monthlyBills.isEmpty) {
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
                child: const Text("No bills found for this month"),
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
        physics: const AlwaysScrollableScrollPhysics(), // Ensures it can be pulled even if list is short
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: monthlyBills.length,
        itemBuilder: (context, index) {
          final p = monthlyBills[index];
          final student = p['studentId'];
          final String? photoUrl = student != null ? student['photoURL'] : null;
          final String status = p['status'] ?? 'pending';

          return Card(
            margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person) : null,
              ),
              title: Text(student?['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("₹${p['amount']} - ${p['title']}"),
                  const SizedBox(height: 4),
                  _buildStatusBadge(status),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaymentDetailScreen(payment: p)),
                ).then((_) => _loadBills()); 
              },
            ),
          );
        },
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    decoration: const InputDecoration(labelText: "Title", hintText: "e.g., Extra Chicken, Damage Fine"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount (₹)", prefixText: "₹ "),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: "Description (Optional)"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill Title and Amount")));
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
                          _loadBills(); 
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Fine created successfully!"), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Failed to create fine"), backgroundColor: Colors.red),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isCreating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("GENERATE"),
              ),
            ],
          );
        },
      ),
    );
  }
}