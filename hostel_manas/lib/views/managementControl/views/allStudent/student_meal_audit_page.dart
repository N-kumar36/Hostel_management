import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class StudentMealAuditPage extends StatefulWidget {
  final String studentName;
  final String studentId;

  const StudentMealAuditPage({
    super.key,
    required this.studentName,
    required this.studentId,
  });

  @override
  State<StudentMealAuditPage> createState() => _StudentMealAuditPageState();
}

class _StudentMealAuditPageState extends State<StudentMealAuditPage> {
  final api = ApiService();

  List<dynamic> calculatedCyclesList = [];
  dynamic _selectedCycle;
  Map<String, dynamic> cycleFilteredSummary = {};

  bool isLoadingInitialCycles = true;
  bool isProcessingMetrics = false;
  String? loadingError;

  @override
  void initState() {
    super.initState();
    _fetchSystemMealCycles();
  }

  Future<void> _fetchSystemMealCycles() async {
    try {
      if (mounted) {
        setState(() {
          isLoadingInitialCycles = true;
          loadingError = null;
        });
      }

      final cyclesResponse = await api.getMealCycleDateBounds();
      if (cyclesResponse['success'] == true && cyclesResponse['cycles'] != null) {
        calculatedCyclesList = cyclesResponse['cycles'];
        if (calculatedCyclesList.isNotEmpty) {
          _selectedCycle = calculatedCyclesList.firstWhere(
            (c) => c['isCurrentActive'] == true,
            orElse: () => calculatedCyclesList.first,
          );
        }
        await _fetchCycleMetrics();
      } else {
        throw Exception("Failed to map operational hostel meal cycles.");
      }
    } catch (e) {
      debugPrint("Error loading cycles pipeline: $e");
      if (mounted) {
        setState(() {
          loadingError = e.toString();
          isLoadingInitialCycles = false;
        });
      }
    }
  }

  Future<void> _fetchCycleMetrics() async {
    if (_selectedCycle == null) {
      if (mounted) setState(() => isLoadingInitialCycles = false);
      return;
    }

    try {
      final summaryResponse = await api.getStudentSummary(
        widget.studentId,
        startDateStr: _selectedCycle!['startDateStr'],
        endDateStr: _selectedCycle!['endDateStr'],
      );

      if (mounted) {
        setState(() {
          cycleFilteredSummary = summaryResponse;
          isLoadingInitialCycles = false;
          isProcessingMetrics = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching individual cycle metrics: $e");
      if (mounted) {
        setState(() {
          loadingError = e.toString();
          isLoadingInitialCycles = false;
          isProcessingMetrics = false;
        });
      }
    }
  }

  void _onCycleChanged(dynamic newCycle) {
    if (newCycle == null) return;
    setState(() {
      _selectedCycle = newCycle;
      isProcessingMetrics = true;
    });
    _fetchCycleMetrics();
  }

  void _viewFullScreenReceipt(String imgUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InteractiveViewer(
            child: Image.network(imgUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = (cycleFilteredSummary['activeSubscription'] as Map?)?.cast<String, dynamic>();
    final List votesHistory = cycleFilteredSummary['votedMealsHistory'] ?? [];
    final List paymentsList = cycleFilteredSummary['finesPaymentHistory'] ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "${widget.studentName}'s Meal Audit",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFF2F2F7), width: 1)),
      ),
      body: isLoadingInitialCycles
          ? const Center(child: CircularProgressIndicator(color: Colors.purple, strokeWidth: 3))
          : loadingError != null
              ? _buildErrorScreen()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeading("Select Accounting Timeframe Window"),
                      const SizedBox(height: 10),
                      _buildCycleSelectorDropdown(),
                      const SizedBox(height: 24),

                      if (isProcessingMetrics)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator(color: Colors.purple, strokeWidth: 3)),
                        )
                      else ...[
                        _buildSectionHeading("Cycle Summary Metrics Dashboard"),
                        const SizedBox(height: 12),
                        _buildMetricsGridCard(),
                        const SizedBox(height: 28),

                        _buildSectionHeading("Subscription Lifecycle Status"),
                        const SizedBox(height: 12),
                        sub == null ? _buildNoSubscriptionView() : _buildQuotaOverviewCard(sub),
                        if (sub != null) ...[
                          const SizedBox(height: 14),
                          _buildDetailedChipsGrid(sub),
                        ],
                        const SizedBox(height: 28),

                        _buildSectionHeading("Meal Vote & Consumption Log History"),
                        const SizedBox(height: 12),
                        _buildVoteHistorySection(votesHistory),
                        const SizedBox(height: 28),

                        _buildSectionHeading("Payment Actions & Verification Receipts"),
                        const SizedBox(height: 12),
                        _buildPaymentSection(paymentsList),
                      ]
                    ],
                  ),
                ),
    );
  }

  Widget _buildCycleSelectorDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: _selectedCycle,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.purple, size: 22),
          items: calculatedCyclesList.map((cycle) {
            final bool isLive = cycle['isCurrentActive'] == true;
            return DropdownMenuItem<dynamic>(
              value: cycle,
              child: Row(
                children: [
                  Icon(
                    isLive ? Icons.lens_rounded : Icons.history_toggle_off_rounded, 
                    color: isLive ? Colors.green.shade600 : Colors.grey.shade400, 
                    size: isLive ? 12 : 18
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cycle['label'], 
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: isLive ? FontWeight.bold : FontWeight.w500, 
                        color: isLive ? Colors.black87 : Colors.black54
                      )
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: _onCycleChanged,
        ),
      ),
    );
  }

  Widget _buildMetricsGridCard() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statMetricCard("Total Votes", "${cycleFilteredSummary['studentOwnVotes'] ?? 0}", Colors.blue.shade700, Icons.assignment_turned_in_rounded),
        _statMetricCard("Guest Meals", "${cycleFilteredSummary['totalGuestVotes'] ?? 0}", Colors.purple.shade700, Icons.people_alt_rounded),
        _statMetricCard("Served Meals", "${cycleFilteredSummary['totalServed'] ?? 0}", Colors.green.shade700, Icons.restaurant_rounded),
        _statMetricCard("Pending Fines", "₹${cycleFilteredSummary['pendingFines'] ?? 0}", Colors.red.shade700, Icons.error_outline_rounded),
      ],
    );
  }

  Widget _statMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildQuotaOverviewCard(Map<String, dynamic> sub) {
    final maxLimits = sub['maxLimits'] ?? {};
    final usage = sub['usage'] ?? {};

    int totalAllowed = 0;
    int totalUsed = 0;
    maxLimits.forEach((k, v) => totalAllowed += (v as num?)?.toInt() ?? 0);
    usage.forEach((k, v) => totalUsed += (v as num?)?.toInt() ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (sub['planType'] ?? "Routine Plan").toString().toUpperCase(), 
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.purple, letterSpacing: 0.3)
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sub['status']?.toString().toUpperCase() ?? "ACTIVE", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green.shade800)
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _counterElement("Total Quota", "$totalAllowed", Colors.black87),
              _counterElement("Consumed", "$totalUsed", Colors.orange.shade800),
              _counterElement("Remaining", "${totalAllowed - totalUsed}", Colors.green.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterElement(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDetailedChipsGrid(Map<String, dynamic> sub) {
    final usage = sub['usage'] ?? {};
    final maxLimits = sub['maxLimits'] ?? {};

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _categoryRowChip("Veg", usage['veg'], maxLimits['veg']),
        _categoryRowChip("Chicken", usage['chicken'], maxLimits['chicken']),
        _categoryRowChip("Fish", usage['fish'], maxLimits['fish']),
        _categoryRowChip("Egg", usage['egg'], maxLimits['egg']),
        _categoryRowChip("Paneer", usage['paneer'], maxLimits['paneer']),
        _categoryRowChip("Mutton", usage['mutton'], maxLimits['mutton']),
      ],
    );
  }

  Widget _categoryRowChip(String label, dynamic usedVal, dynamic maxVal) {
    int used = (usedVal as num?)?.toInt() ?? 0;
    int max = (maxVal as num?)?.toInt() ?? 0;
    if (max <= 0) return const SizedBox.shrink();

    bool isFull = used >= max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFull ? Colors.red.shade50 : Colors.white, 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: isFull ? Colors.red.shade100 : Colors.grey.shade200, width: 1.1)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label  ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isFull ? Colors.red.shade800 : Colors.black54)),
          Text("$used/$max", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isFull ? Colors.red.shade900 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildVoteHistorySection(List votes) {
  if (votes.isEmpty) {
    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.shade200),
      ), 
      child: Center(
        child: Text(
          "No meal votes logged for this cycle.", 
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(24), 
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: votes.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
      itemBuilder: (context, index) {
        final item = votes[index];
        final bool isServed = item['isServed'] == true;
        final bool hasVoted = item['voted'] == true;
        final int guests = (item['guestCount'] as num?)?.toInt() ?? 0;
        
        //  New optimized key variables from the API payload updates
        final String totalMealsInSlot = item['mealsNum'] ?? "0";
        final String menuBaseType = (item['manu'] ?? 'N/A').toString().toUpperCase();
        final String selectedPref = (item['itemPreference'] ?? 'N/A').toString().replaceAll('_', ' ').toUpperCase();
        final String staffServedName = item['ServedBy'] ?? 'N/A';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['date'] ?? 'N/A', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                Text(
                  "Meal NO: $totalMealsInSlot", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          (item['slot'] ?? 'Day').toString().toUpperCase(), 
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          "MENU: $menuBaseType", 
                          style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (guests > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          "+ $guests Guests", 
                          style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                      ]
                    ],
                  ),
                  if (hasVoted) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Preference: $selectedPref",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                  ],
                  if (isServed) ...[
                    const SizedBox(height: 2),
                    Text(
                      "Served By: $staffServedName",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green.shade700),
                    ),
                  ],
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isServed ? Colors.green.shade50 : (!hasVoted ? Colors.grey.shade100 : Colors.blue.shade50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isServed ? "SERVED" : (!hasVoted ? "NOT VOTED" : "VOTED"),
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: isServed ? Colors.green.shade800 : (!hasVoted ? Colors.grey.shade600 : Colors.blue.shade800),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildPaymentSection(List payments) {
    if (payments.isEmpty) {
      return Container(
        width: double.infinity, 
        padding: const EdgeInsets.all(20), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), 
        child: Center(child: Text("No fine collections logged in this window.", style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500)))
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payments.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
        itemBuilder: (context, index) {
          final fine = payments[index];
          final String? receipt = fine['paymentScreenshot'];
          final bool isPaid = fine['status'] == 'success';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(fine['title'] ?? 'Fine Dues Charge', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text("Amount: ₹${fine['amount'] ?? 0}", style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPaid && receipt != null && receipt.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: const Icon(Icons.receipt_long_rounded, color: Colors.purple, size: 20),
                      onPressed: () => _viewFullScreenReceipt(receipt),
                      tooltip: "View Receipt Image",
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade50 : (fine['status'] == 'processing' ? Colors.blue.shade50 : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid ? "PAID" : fine['status'].toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: isPaid ? Colors.green.shade800 : (fine['status'] == 'processing' ? Colors.blue.shade800 : Colors.amber.shade900)
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

  Widget _buildNoSubscriptionView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(Icons.no_food_rounded, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 12),
          const Text("No active package subscription tracked this month.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1.2)),
      );

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text("Error loading data dimensions: $loadingError", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 14),
            TextButton(onPressed: _fetchSystemMealCycles, child: const Text("Retry Connection", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
          ],
        ),
      ),
    );
  }
}