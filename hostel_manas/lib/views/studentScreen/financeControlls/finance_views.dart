import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'finance_controller.dart';

class FinanceViews extends StatefulWidget {
  const FinanceViews({super.key});

  @override
  State<FinanceViews> createState() => _FinanceViewsState();
}

class _FinanceViewsState extends State<FinanceViews>
    with SingleTickerProviderStateMixin {
  final FinanceController _controller = FinanceController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.initialize(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _viewReceiptImageDialog(String studentName, String imgUrl) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black87,
                title: Text(
                  "$studentName's Slip",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imgUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 44,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Failed to download image attachment statement.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDateSelectionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Operational Target Cycle",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _controller.calculatedCyclesList.isEmpty
                    ? const Center(
                        child: Text(
                          "No compiled financial logging sets discovered.",
                        ),
                      )
                    : ListView.builder(
                        itemCount: _controller.calculatedCyclesList.length,
                        itemBuilder: (context, index) {
                          final cycle = _controller.calculatedCyclesList[index];
                          final bool isLive = cycle['isCurrentActive'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? Colors.deepPurple.withOpacity(0.04)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isLive
                                    ? Colors.deepPurple.withOpacity(0.2)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isLive
                                    ? Icons.bolt_rounded
                                    : Icons.history_rounded,
                                color: isLive
                                    ? Colors.deepPurple
                                    : Colors.grey.shade600,
                              ),
                              title: Text(
                                cycle['label'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isLive
                                      ? Colors.deepPurple.shade900
                                      : Colors.black87,
                                ),
                              ),
                              trailing: isLive
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        "LIVE",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                    ),
                              onTap: () {
                                Navigator.pop(bc);
                                _controller.selectCycle(cycle, () {
                                  if (mounted) setState(() {});
                                }, _showErrorSnackBar);
                              },
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 28),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.date_range_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                title: const Text(
                  "Custom Range Picker Coordinates",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  "Define specific custom boundaries",
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(bc);
                  _showNativeDatePicker(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNativeDatePicker(BuildContext context) async {
    // ⚡ Normalize today's date coordinates to absolute midnight to prevent hour assertion offsets
    final DateTime totalTodayMidnight = DateTime(
      _controller.lastAvailableMealDate.year,
      _controller.lastAvailableMealDate.month,
      _controller.lastAvailableMealDate.day,
    );

    // Ensure our initial state values do not overshoot midnight boundaries
    final DateTime safeStart = _controller.startDate.isAfter(totalTodayMidnight)
        ? totalTodayMidnight
        : _controller.startDate;

    final DateTime safeEnd = _controller.endDate.isAfter(totalTodayMidnight)
        ? totalTodayMidnight
        : _controller.endDate;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: _controller.firstAvailableMealDate,
      lastDate:
          totalTodayMidnight, // Enforces midnight upper ceiling constraint
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      helpText: "Select Audit Duration Bound",
    );

    if (picked != null) {
      _controller.selectCustomRange(picked, () {
        if (mounted) setState(() {});
      }, _showErrorSnackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Finance Analytics",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.indigo,
            ),
            onPressed: _controller.exportToPdf,
            tooltip: "Generate Report",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Timeline Scope Widget Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: InkWell(
              onTap: () => _showDateSelectionOptions(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.deepPurple.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${DateFormat('dd MMM yyyy').format(_controller.startDate)}  ➔  ${DateFormat('dd MMM yyyy').format(_controller.endDate)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Focus Cycle info tag strip
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 18,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 8),
                Text(
                  "Focus Target Window: Operational Cycle #${_controller.currentActiveCycleNumber}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),

          if (_controller.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
            )
          else ...[
            _buildFinancialOverviewGrid(),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple.shade700,
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: Colors.deepPurple.shade700,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: "Student Ledgers"),
                  Tab(text: "Procurements"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildStudentUsageTab(), _buildProcurementTab()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialOverviewGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "TOTAL INFLOW FUNDS",
                  "₹${_controller.totalCollections}",
                  Colors.green.shade700,
                  Icons.arrow_upward_rounded,
                ),
              ),
              Expanded(
                child: _buildMetricCard(
                  "TOTAL PROCUREMENT OUT",
                  "₹${_controller.totalExpenses}",
                  Colors.orange.shade800,
                  Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "NET BAL CASH POOL",
                  "₹${_controller.netBalance}",
                  Colors.indigo.shade700,
                  Icons.account_balance_wallet_rounded,
                ),
              ),
              Expanded(
                child: _buildMetricCard(
                  "MEALS COUNT LOGS",
                  "${_controller.totalMealsServed} Plates",
                  Colors.blueGrey.shade700,
                  Icons.restaurant_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 18, color: color.withOpacity(0.4)),
        ],
      ),
    );
  }

  Widget _buildStudentUsageTab() {
    if (_controller.studentUsageList.isEmpty) {
      return Center(
        child: Text(
          "No student records found in this cycle range.",
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      itemCount: _controller.studentUsageList.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final student = _controller.studentUsageList[index];
        final bool isPaid = student['status'] == 'success';
        final String? receiptFileUrl = student['paymentScreenshot'];
        final String? photoUrl = student['photoURL'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade100,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Icon(Icons.person_rounded, color: Colors.grey.shade400)
                  : null,
            ),
            title: Text(
              student['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  student['title'] ?? student['email'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Consumed: ${student['consumed']} Meals",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isPaid &&
                        receiptFileUrl != null &&
                        receiptFileUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          backgroundColor: Colors.deepPurple.shade50
                              .withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.receipt_long_rounded,
                          size: 14,
                          color: Colors.deepPurple,
                        ),
                        label: const Text(
                          "View Slip",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        onPressed: () => _viewReceiptImageDialog(
                          student['name'],
                          receiptFileUrl,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${student['amount']}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade50
                        : (student['status'] == 'processing'
                              ? Colors.blue.shade50
                              : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid
                        ? "PAID"
                        : student['status'].toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isPaid
                          ? Colors.green.shade800
                          : (student['status'] == 'processing'
                                ? Colors.blue.shade800
                                : Colors.amber.shade900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcurementTab() {
    if (_controller.expenseItemsList.isEmpty) {
      return Center(
        child: Text(
          "No procurement items logged in this window.",
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      itemCount: _controller.expenseItemsList.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final expense = _controller.expenseItemsList[index];
        final bool isBought = expense['isBought'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isBought ? Colors.orange.shade50 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBought
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_basket_outlined,
                color: isBought ? Colors.orange.shade800 : Colors.grey,
              ),
            ),
            title: Text(
              expense['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expense['description'] != null &&
                    expense['description'].isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expense['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expense['createdBy'] ?? 'Manager',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expense['dateTime'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${expense['price']}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isBought
                        ? Colors.orange.shade900
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isBought
                        ? Colors.orange.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isBought ? "BOUGHT" : "CART LIST",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isBought
                          ? Colors.orange.shade900
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
