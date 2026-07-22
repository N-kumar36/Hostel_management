import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:intl/intl.dart';

class MealSubscriptionsPage extends StatefulWidget {
  const MealSubscriptionsPage({super.key});

  @override
  State<MealSubscriptionsPage> createState() => _MealSubscriptionsPageState();
}

class _MealSubscriptionsPageState extends State<MealSubscriptionsPage> {
  final api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> allSubscriptions = [];
  List<dynamic> _filteredSubscriptions = [];
  List<dynamic> availablePlans = [];
  bool isLoading = true;
  bool isBulkCompiling = false; // Tracker for the compile all operations
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_onSearchOrFilterChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchOrFilterChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        api.getManagerSubscriptions(),
        api.getmealPackages(),
      ]);

      if (mounted) {
        setState(() {
          allSubscriptions = results[0] as List<dynamic>;
          final plansData = results[1] as Map<String, dynamic>;
          availablePlans = plansData['data'] ?? plansData['packages'] ?? [];
          _onSearchOrFilterChanged();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🌟 UPDATED METHOD: Allows compilation if there are either PENDING or ACTIVE subscriptions
  Future<void> _handleCompileAllSubscriptions() async {
    final int eligibleCount = allSubscriptions.where((s) {
      final String status = s['status'].toString().toLowerCase();
      return status == 'pending' || status == 'active';
    }).length;

    if (eligibleCount == 0) {
      _showPageSnackBar(
        "No pending or active subscriptions left to compile!",
        Colors.orange,
      );
      return;
    }

    final bool confirm = await _showConfirmDialog(
      "Compile Pack Records",
      "Are you sure you want to batch compile and complete all $eligibleCount pending/active student meal packs?",
    );
    if (!confirm) return;

    setState(() => isBulkCompiling = true);
    try {
      final res = await api.compileAllStudentSubscriptions(); 
      if (res['success'] == true && mounted) {
        _showPageSnackBar(
          res['message'] ?? "All eligible meal packs compiled successfully!",
          Colors.green,
        );
        _fetchData();
      } else if (mounted) {
        _showPageSnackBar(
          res['message'] ?? "Compilation process failed",
          Colors.red,
        );
      }
    } catch (e) {
      _showPageSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isBulkCompiling = false);
    }
  }

  void _onSearchOrFilterChanged() {
    final String query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredSubscriptions = allSubscriptions.where((s) {
        final bool matchesStatus =
            selectedFilter == 'All' ||
            s['status'].toString().toLowerCase() ==
                selectedFilter.toLowerCase();

        if (!matchesStatus) return false;

        final student = s['studentId'] is Map ? s['studentId'] : {};
        final String name = (student['name'] ?? "").toString().toLowerCase();
        final String email = (student['email'] ?? "").toString().toLowerCase();
        final String regNum = (student['regNum'] ?? "").toString().toLowerCase();

        return name.contains(query) || email.contains(query) || regNum.contains(query);
      }).toList();
    });
  }

  // --- EDIT BOTTOM SHEET ---
  void _showEditSheet(Map<String, dynamic> sub) {
    String? rawPlanId = sub['mealsPlanId'] is Map
        ? sub['mealsPlanId']['_id']?.toString()
        : sub['mealsPlanId']?.toString();
        
    String currentPlanId = rawPlanId ?? "";
    String currentStatus = (sub['status'] ?? "pending").toString();
    bool isSaving = false;

    bool planExists = availablePlans.any((p) => p['_id'].toString() == currentPlanId);
    if (!planExists && currentPlanId.isNotEmpty) {
      availablePlans.add({
        '_id': currentPlanId,
        'planType': sub['planType'] ?? 'Existing Plan',
        'monthlyPrice': sub['amount'] ?? 0,
      });
    } else if (currentPlanId.isEmpty && availablePlans.isNotEmpty) {
      currentPlanId = availablePlans[0]['_id'].toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    "Edit Subscription",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "MEAL PLAN",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: currentPlanId.isNotEmpty ? currentPlanId : null,
                    hint: const Text("Select a meal plan"),
                    items: availablePlans.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['_id'].toString(),
                        child: Text("${p['planType']} - ₹${p['monthlyPrice'] ?? p['price'] ?? 0}"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => currentPlanId = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "STATUS",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: currentStatus.toLowerCase(),
                    items: const [
                      DropdownMenuItem(value: "pending", child: Text("Pending")),
                      DropdownMenuItem(value: "active", child: Text("Active")),
                      DropdownMenuItem(value: "completed", child: Text("Completed")),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => currentStatus = val);
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving || currentPlanId.isEmpty
                          ? null
                          : () async {
                              setSheetState(() => isSaving = true);
                              try {
                                final res = await api.updateSubscriptionByManager(
                                  sub['_id'],
                                  currentPlanId,
                                  currentStatus,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  _showPageSnackBar(res['message'] ?? "Updated successfully", Colors.green);
                                  _fetchData();
                                }
                              } catch (e) {
                                if (mounted) _showPageSnackBar("Failed to update", Colors.red);
                              } finally {
                                if (mounted) setSheetState(() => isSaving = false);
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DELETE CONFIRMATION DIALOG ---
  void _showDeleteConfirmation(String subId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Delete Plan?"),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this subscription? This action cannot be undone.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              try {
                final res = await api.deleteSubscriptionByManager(subId);
                if (mounted) {
                  _showPageSnackBar(res['message'] ?? "Deleted successfully", Colors.red);
                  _fetchData();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => isLoading = false);
                  _showPageSnackBar("Failed to delete subscription", Colors.red);
                }
              }
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showPageSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Meal Subscriptions", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isLoading)
            isBulkCompiling
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: "Compile All Packs",
                    icon: const Icon(Icons.bolt, color: Colors.amberAccent),
                    onPressed: _handleCompileAllSubscriptions,
                  ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by student name, email, or reg num...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.green, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchOrFilterChanged();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.green.withOpacity(0.04),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  _filterChip('All'),
                  const SizedBox(width: 8),
                  _filterChip('Active'),
                  const SizedBox(width: 8),
                  _filterChip('Pending'),
                  const SizedBox(width: 8),
                  _filterChip('Completed'),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _filteredSubscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.no_meals_outlined, size: 70, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? "No matches found for search query"
                                  : "No $selectedFilter Subscriptions Listed",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        color: Colors.green,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          itemCount: _filteredSubscriptions.length,
                          itemBuilder: (context, index) {
                            return _buildSubscriptionCard(_filteredSubscriptions[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    bool isSelected = selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => selectedFilter = label);
          _onSearchOrFilterChanged();
        }
      },
      selectedColor: Colors.green,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 12),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    final student = sub['studentId'] is Map ? sub['studentId'] : {};
    final status = (sub['status'] ?? "pending").toString();
    final planType = (sub['planType'] ?? "Meals").toString();
    final month = (sub['month'] ?? "").toString();

    final usage = sub['usage'] ?? {};
    final limits = sub['maxLimits'] ?? {};

    int studentAllowed = 0;
    int studentUsed = 0;

    limits.forEach((key, val) => studentAllowed += (val as num?)?.toInt() ?? 0);
    usage.forEach((key, val) => studentUsed += (val as num?)?.toInt() ?? 0);
    int studentLeft = studentAllowed - studentUsed;

    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'active') statusColor = Colors.green;
    if (status.toLowerCase() == 'completed') statusColor = Colors.blue;

    String formattedDate = "";
    try {
      if (sub['createdAt'] != null) {
        DateTime dt = DateTime.parse(sub['createdAt']);
        formattedDate = DateFormat('MMM dd, yyyy').format(dt.toLocal());
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.green.withOpacity(0.08),
                  child: const Icon(Icons.person, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? "Unknown Student",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student['email'] ?? "No email linked",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${student['department'] ?? 'N/A'} • Reg: ${student['regNum'] ?? 'N/A'}",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text("Subscribed: $formattedDate", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blueGrey, size: 22),
                          onPressed: () => _showEditSheet(sub),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _showDeleteConfirmation(sub['_id']?.toString() ?? ""),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.8),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildIndividualCardMetric("Total Plans", "$studentAllowed", Colors.black87),
                  Container(width: 1, height: 16, color: Colors.grey.shade200),
                  _buildIndividualCardMetric("Consumed", "$studentUsed", Colors.orange.shade800),
                  Container(width: 1, height: 16, color: Colors.grey.shade200),
                  _buildIndividualCardMetric("Remaining", "$studentLeft", Colors.green.shade700),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      month,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    planType,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              "Detailed Category Breakdown:",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildUsageChip("Veg", usage['veg'], limits['veg']),
                _buildUsageChip("Chicken", usage['chicken'], limits['chicken']),
                _buildUsageChip("Fish", usage['fish'], limits['fish']),
                _buildUsageChip("Egg", usage['egg'], limits['egg']),
                _buildUsageChip("Paneer", usage['paneer'], limits['paneer']),
                _buildUsageChip("Mutton", usage['mutton'], limits['mutton']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualCardMetric(String label, String value, Color textAccentColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 15, color: textAccentColor, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildUsageChip(String label, dynamic usedVal, dynamic maxVal) {
    int used = (usedVal as num?)?.toInt() ?? 0;
    int max = (maxVal as num?)?.toInt() ?? 0;
    if (max <= 0) return const SizedBox.shrink();

    bool isFull = used >= max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFull ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isFull ? Colors.red.shade100 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          Text(
            "$used/$max",
            style: TextStyle(fontSize: 11, color: isFull ? Colors.red : Colors.black87, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}