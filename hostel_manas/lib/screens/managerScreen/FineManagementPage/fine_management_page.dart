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

  // State for Students
  List<dynamic> allStudents = [];
  String searchQuery = "";

  // Controllers for Prices
  final TextEditingController _monthlyFeeController = TextEditingController(text: "1500");
  final TextEditingController _vegPriceController = TextEditingController(text: "35");
  final TextEditingController _eggPriceController = TextEditingController(text: "45");
  final TextEditingController _paneerPriceController = TextEditingController(text: "45");
  final TextEditingController _chickenPriceController = TextEditingController(text: "65");
  final TextEditingController _fishPriceController = TextEditingController(text: "55");
  final TextEditingController _muttonPriceController = TextEditingController(text: "85");

  // ✅ New Controllers for Manager UPI
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _merchantNameController = TextEditingController();

  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  List<dynamic> pendingPayments = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _loadPendingFines(),
      _fetchSavedPrices(),
      _fetchAllStudents(),
      _fetchUpiDetails(), // ✅ Fetch UPI on load
    ]);
    setState(() => isLoading = false);
  }

  Future<void> _fetchUpiDetails() async {
    try {
      final data = await api.getManagerUpi();
      if (data != null) {
        setState(() {
          _upiIdController.text = data['upiId'] ?? "";
          _merchantNameController.text = data['merchantName'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("UPI Load Error: $e");
    }
  }

  Future<void> _saveUpiSettings() async {
    if (_upiIdController.text.isEmpty || _merchantNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all UPI fields"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => isLoading = true);
    final success = await api.saveUpiDetails({
      "upiId": _upiIdController.text.trim(),
      "merchantName": _merchantNameController.text.trim(),
    });
    setState(() => isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("UPI Settings Updated!"), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _fetchAllStudents() async {
    try {
      final response = await api.getAllStudents();
      setState(() => allStudents = response ?? []);
    } catch (e) {
      debugPrint("Students Load Error: $e");
    }
  }

  Future<void> _loadPendingFines() async {
    try {
      final data = await api.getPendingFines();
      setState(() => pendingPayments = data ?? []);
    } catch (e) {
      debugPrint("Fines Load Error: $e");
    }
  }

  Future<void> _fetchSavedPrices() async {
    try {
      final response = await api.getMealPriceTable();
      if (response != null) {
        final Map<String, dynamic> prices = response['prices'] ?? {};
        setState(() {
          _monthlyFeeController.text = response['baseFee']?.toString() ?? "1500";
          if (prices.containsKey('veg')) _vegPriceController.text = prices['veg'].toString();
          if (prices.containsKey('egg')) _eggPriceController.text = prices['egg'].toString();
          if (prices.containsKey('paneer')) _paneerPriceController.text = prices['paneer'].toString();
          if (prices.containsKey('chicken')) _chickenPriceController.text = prices['chicken'].toString();
          if (prices.containsKey('fish')) _fishPriceController.text = prices['fish'].toString();
          if (prices.containsKey('mutton')) _muttonPriceController.text = prices['mutton'].toString();
        });
      }
    } catch (e) {
      debugPrint("Price Load Error: $e");
    }
  }

  Future<void> _savePricePlan() async {
    setState(() => isLoading = true);
    final success = await api.saveMealPriceTable({
      "baseFee": int.tryParse(_monthlyFeeController.text),
      "prices": {
        "veg": int.tryParse(_vegPriceController.text),
        "egg": int.tryParse(_eggPriceController.text),
        "paneer": int.tryParse(_paneerPriceController.text),
        "chicken": int.tryParse(_chickenPriceController.text),
        "fish": int.tryParse(_fishPriceController.text),
        "mutton": int.tryParse(_muttonPriceController.text),
      }
    });
    setState(() => isLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Price Plan Saved Successfully!"), backgroundColor: Colors.blue),
      );
    }
  }

  Future<void> _generateBulkFees() async {
    bool confirm = await _showConfirmDialog(
      "Generate All Fees?",
      "This Payment for Monthly fee (₹${_monthlyFeeController.text}) + consumption for $selectedMonth.",
    );

    if (confirm) {
      setState(() => isLoading = true);
      try {
        final result = await api.generateBulkFines({
          "month": selectedMonth,
          "baseFee": _monthlyFeeController.text,
          "veg": _vegPriceController.text,
          "egg": _eggPriceController.text,
          "paneer": _paneerPriceController.text,
          "chicken": _chickenPriceController.text,
          "fish": _fishPriceController.text,
          "mutton": _muttonPriceController.text,
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bills generated successfully!"), backgroundColor: Colors.green),
          );
          _loadPendingFines();
        }
      } catch (e) {
        debugPrint("Generation Error: $e");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // ✅ Increased to 3 for Settings
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Manager Panel", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Bills"),
              Tab(icon: Icon(Icons.people), text: "Students"),
              Tab(icon: Icon(Icons.settings), text: "Settings"), // ✅ Added Settings
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Dashboard / Pending Verifications
            RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildGenerationCard(),
                  const SizedBox(height: 25),
                  const Text(
                    "PENDING VERIFICATIONS",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  isLoading ? const Center(child: CircularProgressIndicator()) : _buildPaymentList(),
                ],
              ),
            ),
            // Tab 2: All Students List
            _buildStudentListSection(),
            // Tab 3: ✅ Settings Section (Meal Prices & UPI)
            RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPriceSettingsCard(),
                  const SizedBox(height: 20),
                  _buildUpiSettingsCard(), // ✅ Added UPI Card
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ New Widget: UPI Settings UI
  Widget _buildUpiSettingsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Colors.deepPurple, size: 20),
                    SizedBox(width: 8),
                    Text("UPI Payment Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _saveUpiSettings,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("Update UPI"),
                )
              ],
            ),
            const Divider(height: 20),
            const Text("This information will be used to generate the QR code for students.", 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: _upiIdController,
              decoration: InputDecoration(
                labelText: "UPI ID",
                hintText: "example@okaxis",
                prefixIcon: const Icon(Icons.alternate_email, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _merchantNameController,
              decoration: InputDecoration(
                labelText: "Merchant / Display Name",
                hintText: "Manager Name - Hostel",
                prefixIcon: const Icon(Icons.person_outline, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListSection() {
    final filteredList = allStudents.where((s) => s['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search student by name...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: filteredList.isEmpty 
          ? const Center(child: Text("No students found"))
          : ListView.builder(
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final student = filteredList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: student['photoURL'] != null && student['photoURL'] != "" 
                      ? NetworkImage(student['photoURL']) : null,
                    child: (student['photoURL'] == null || student['photoURL'] == "") 
                      ? const Icon(Icons.person) : null,
                  ),
                  title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Email: ${student['email']}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.redAccent),
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

  void _showIndividualFineDialog(dynamic student) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Create Bill for ${student['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController, 
              decoration: const InputDecoration(labelText: "Title (e.g. Penalty, Extra Meal)")
            ),
            TextField(
              controller: amountController, 
              keyboardType: TextInputType.number, 
              decoration: const InputDecoration(labelText: "Amount (₹)")
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if(titleController.text.isEmpty || amountController.text.isEmpty) return;
              
              final res = await api.createIndividualFine({
                "studentId": student['_id'],
                "amount": int.parse(amountController.text),
                "title": titleController.text,
                "description": "Individually generated fee by manager"
              });

              if (res) {
                Navigator.pop(context);
                _loadPendingFines();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill generated!")));
              }
            },
            child: const Text("Generate"),
          )
        ],
      ),
    );
  }

  Widget _buildPriceSettingsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text("Set Meal Prices", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _savePricePlan,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text("Save Plan"),
                )
              ],
            ),
            const Divider(height: 20),
            _priceInput("Base Monthly Plan", _monthlyFeeController, Icons.calendar_month, Colors.blue),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _priceInput("Veg", _vegPriceController, Icons.eco, Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: _priceInput("Egg", _eggPriceController, Icons.egg, Colors.orange)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _priceInput("Paneer", _paneerPriceController, Icons.restaurant, Colors.amber)),
                const SizedBox(width: 10),
                Expanded(child: _priceInput("Chicken", _chickenPriceController, Icons.kebab_dining, Colors.red)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _priceInput("Fish", _fishPriceController, Icons.set_meal, Colors.blueAccent)),
                const SizedBox(width: 10),
                Expanded(child: _priceInput("Mutton", _muttonPriceController, Icons.restaurant_menu, Colors.brown)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceInput(String label, TextEditingController controller, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: iconColor),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          prefixText: "₹",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildGenerationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(
            "GENERATE BILLS FOR ${selectedMonth.toUpperCase()}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _generateBulkFees,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("RUN MONTHLY CALCULATION", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    if (pendingPayments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text("No pending payments.", style: TextStyle(color: Colors.grey))),
      );
    }
    return Column(
      children: pendingPayments.map((payment) {
        final student = payment['studentId'];
        final String studentName = student?['name'] ?? "Unknown Student";
        final String photo = student?['photoURL'] ?? "";

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
            ),
            title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("₹${payment['amount']} - ${payment['title']}"),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentDetailScreen(payment: payment),
                  ),
                ).then((_) => _loadPendingFines());
              },
              child: const Text("REVIEW"),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _showConfirmDialog(String title, String desc) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title),
        content: Text(desc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("GENERATE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;
  }
}