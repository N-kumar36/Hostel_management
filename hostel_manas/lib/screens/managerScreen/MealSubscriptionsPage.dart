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
  List<dynamic> allSubscriptions = [];
  List<dynamic> availablePlans = [];
  bool isLoading = true;
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchData();
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

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- EDIT BOTTOM SHEET ---
  void _showEditSheet(Map<String, dynamic> sub) {
    String currentPlanId = sub['mealsPlanId'] is Map
        ? sub['mealsPlanId']['_id']
        : sub['mealsPlanId'];
    String currentStatus = sub['status'].toString();
    bool isSaving = false;

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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: currentPlanId,
                    items: availablePlans.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['_id'].toString(),
                        child: Text(
                          "${p['planType']} - ₹${p['monthlyPrice'] ?? p['price']}",
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => currentPlanId = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "STATUS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: currentStatus.toLowerCase(),
                    items: const [
                      DropdownMenuItem(
                        value: "pending",
                        child: Text("Pending"),
                      ),
                      DropdownMenuItem(value: "active", child: Text("Active")),
                      DropdownMenuItem(
                        value: "completed",
                        child: Text("Completed"),
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setSheetState(() => isSaving = true);
                              try {
                                final res = await api
                                    .updateSubscriptionByManager(
                                      sub['_id'],
                                      currentPlanId,
                                      currentStatus,
                                    );
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message']),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _fetchData();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Failed to update"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted)
                                  setSheetState(() => isSaving = false);
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "SAVE CHANGES",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              setState(() => isLoading = true);
              try {
                final res = await api.deleteSubscriptionByManager(subId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? "Deleted successfully"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _fetchData();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Failed to delete subscription"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSubs = allSubscriptions.where((s) {
      if (selectedFilter == 'All') return true;
      return s['status'].toString().toLowerCase() ==
          selectedFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Meal Subscriptions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    "Filter: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
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
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : filteredSubs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.no_meals_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No $selectedFilter Subscriptions",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: Colors.green,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredSubs.length,
                      itemBuilder: (context, index) {
                        return _buildSubscriptionCard(filteredSubs[index]);
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
        if (selected) setState(() => selectedFilter = label);
      },
      selectedColor: Colors.green,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    final student = sub['studentId'] is Map ? sub['studentId'] : {};
    final status = sub['status'].toString();
    final planType = sub['planType'].toString();
    final month = sub['month'].toString();

    final usage = sub['usage'] ?? {};
    final limits = sub['maxLimits'] ?? {};

    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'active') statusColor = Colors.green;
    if (status.toLowerCase() == 'completed') statusColor = Colors.blue;

    String formattedDate = "";
    try {
      DateTime dt = DateTime.parse(sub['createdAt']);
      formattedDate = DateFormat('MMM dd, yyyy').format(dt.toLocal());
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.person, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? "Unknown Student",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${student['department'] ?? 'N/A'} • Reg: ${student['regNum'] ?? 'N/A'}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Subscribed: $formattedDate",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // ✨ Status Badge & Both Edit/Delete Buttons ✨
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.grey),
                          onPressed: () => _showEditSheet(sub),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(top: 8, right: 8),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _showDeleteConfirmation(sub['_id']),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(top: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      month,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Text(
                  planType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              "Consumption Overview:",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
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

  Widget _buildUsageChip(String label, dynamic usedVal, dynamic maxVal) {
    int used = (usedVal as num?)?.toInt() ?? 0;
    int max = (maxVal as num?)?.toInt() ?? 0;
    if (max <= 0) return const SizedBox.shrink();

    bool isFull = used >= max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFull ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFull ? Colors.red.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "$used/$max",
            style: TextStyle(
              fontSize: 12,
              color: isFull ? Colors.red : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
