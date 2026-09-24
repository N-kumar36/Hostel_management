import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class StudentPaymentScreen extends StatefulWidget {
  const StudentPaymentScreen({super.key});

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  // ---------------------------------------------------------------------------
  // THEME
  // ---------------------------------------------------------------------------

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _primaryDark => const Color(0xFF3F35A8);

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _divider => Theme.of(context).dividerColor;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _subtleSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF3F4F6);

  Color get _softPrimarySurface =>
      _isDark ? const Color(0xFF292650) : const Color(0xFFEEF2FF);

  // Semantic colors remain fixed so payment status meaning stays consistent.
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color processing = Color(0xFF2563EB);

  // ---------------------------------------------------------------------------
  // SERVICES / CONTROLLERS
  // ---------------------------------------------------------------------------

  final ApiService api = ApiService();

  final TextEditingController _searchController = TextEditingController();

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  bool isLoading = false;

  String selectedFilter = "All";

  List<dynamic> allPayments = [];
  List<dynamic> filteredPayments = [];

  String? activeSubscriptionId;

  // ---------------------------------------------------------------------------
  // AMOUNT HELPER
  // ---------------------------------------------------------------------------

  double _getAmount(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  // ---------------------------------------------------------------------------
  // PREVIOUS CYCLE DETECTION
  // ---------------------------------------------------------------------------

  bool _isPreviousCycle(dynamic payment) {
    if (payment is Map && payment.containsKey('belongsToCurrentCycle')) {
      return payment['belongsToCurrentCycle'] == false;
    }

    return payment['isMealPackage'] == true;
  }

  // ---------------------------------------------------------------------------
  // STATUS HELPERS
  // ---------------------------------------------------------------------------

  String _getStatus(dynamic payment) {
    return payment['status']?.toString().toLowerCase() ?? 'pending';
  }

  bool _isPaid(dynamic payment) {
    return _getStatus(payment) == 'success';
  }

  bool _isProcessing(dynamic payment) {
    return _getStatus(payment) == 'processing';
  }

  // ---------------------------------------------------------------------------
  // FINANCIAL SUMMARY
  // ---------------------------------------------------------------------------

  double get totalOutstandingDebt {
    return allPayments
        .where((payment) {
          final status = _getStatus(payment);

          return status == 'pending' || status == 'processing';
        })
        .fold(0.0, (sum, payment) => sum + _getAmount(payment['amount']));
  }

  double get currentFinesPaid {
    return allPayments
        .where((payment) {
          return _getStatus(payment) == 'success' && !_isPreviousCycle(payment);
        })
        .fold(0.0, (sum, payment) => sum + _getAmount(payment['amount']));
  }

  double get currentFinesPending {
    return allPayments
        .where((payment) {
          final status = _getStatus(payment);

          final isPending = status == 'pending' || status == 'processing';

          return isPending && !_isPreviousCycle(payment);
        })
        .fold(0.0, (sum, payment) => sum + _getAmount(payment['amount']));
  }

  double get previousCyclePendingAmount {
    return allPayments
        .where((payment) {
          final status = _getStatus(payment);

          final isPending = status == 'pending' || status == 'processing';

          return isPending && _isPreviousCycle(payment);
        })
        .fold(0.0, (sum, payment) => sum + _getAmount(payment['amount']));
  }

  // ---------------------------------------------------------------------------
  // INIT / DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterData);

    _fetchData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterData);
    _searchController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FETCH DATA
  // ---------------------------------------------------------------------------

  Future<void> _fetchData({bool showLoader = true}) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await api.getAllPaymentHistory();

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          allPayments = response['data'] ?? [];
          activeSubscriptionId = response['activeSubscriptionId']?.toString();
        });

        _filterData();
      } else {
        _showMessage(
          response['message']?.toString() ?? 'Unable to load payment records.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("Error fetching payments: $e");

      if (mounted) {
        _showMessage('Unable to load payment records.', isError: true);
      }
    } finally {
      if (mounted && showLoader) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH / FILTER
  // ---------------------------------------------------------------------------

  void _filterData() {
    final query = _searchController.text.toLowerCase().trim();

    final result = allPayments.where((payment) {
      final student = payment['studentId'] ?? {};

      final name = student['name']?.toString().toLowerCase() ?? '';

      final registration =
          student['registrationNumber']?.toString().toLowerCase() ?? '';

      final isPrevious = _isPreviousCycle(payment);

      final matchesSearch =
          query.isEmpty || name.contains(query) || registration.contains(query);

      bool matchesFilter = true;

      if (selectedFilter == "Current") {
        matchesFilter = !isPrevious;
      } else if (selectedFilter == "Previous") {
        matchesFilter = isPrevious;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    if (!mounted) return;

    setState(() {
      filteredPayments = result;
    });
  }

  void _changeFilter(String filter) {
    if (selectedFilter == filter) return;

    setState(() {
      selectedFilter = filter;
    });

    _filterData();
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: isError ? danger : success,
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Container(
      height: height * 0.90,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildTopBar(),

          Expanded(
            child: RefreshIndicator(
              color: _primary,
              backgroundColor: _surface,
              onRefresh: () => _fetchData(showLoader: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildSummarySection()),

                  SliverToBoxAdapter(child: _buildSearchSection()),

                  SliverToBoxAdapter(child: _buildFilterSection()),

                  if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _LoadingState(),
                    )
                  else if (filteredPayments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _buildResultsHeader()),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final payment = Map<String, dynamic>.from(
                            filteredPayments[index],
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPaymentCard(payment),
                          );
                        }, childCount: filteredPayments.length),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP BAR
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: _isDark
                  ? const Color(0xFF4B5563)
                  : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_primary, _primaryDark]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Payment Ledger",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Student payment & dues overview",
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Material(
                color: _subtleSurface,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => Navigator.pop(context),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.close_rounded,
                      color: _textSecondary,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.check_circle_rounded,
                  label: "Current Paid",
                  amount: currentFinesPaid,
                  color: success,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.pending_actions_rounded,
                  label: "Current Due",
                  amount: currentFinesPending,
                  color: _primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _buildPreviousSummary(),

          const SizedBox(height: 10),

          _buildTotalSummary(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.18 : 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),

              const Spacer(),

              Icon(
                Icons.trending_flat_rounded,
                color: color.withOpacity(0.45),
                size: 17,
              ),
            ],
          ),

          const SizedBox(height: 11),

          Text(
            "₹${amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSummary() {
    final hasDebt = previousCyclePendingAmount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: hasDebt
            ? (_isDark ? const Color(0xFF351C23) : const Color(0xFFFFF1F2))
            : _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: hasDebt ? danger.withOpacity(0.16) : _divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: hasDebt ? danger.withOpacity(0.10) : _subtleSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 17,
              color: hasDebt ? danger : _textSecondary,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Previous Cycle",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Outstanding balance from older packages",
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Text(
            "₹${previousCyclePendingAmount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: hasDebt ? danger : _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary() {
    final hasDebt = totalOutstandingDebt > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasDebt
              ? const [Color(0xFF111827), Color(0xFF374151)]
              : const [Color(0xFF047857), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (hasDebt ? Colors.black : success).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              hasDebt
                  ? Icons.account_balance_wallet_rounded
                  : Icons.verified_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "TOTAL OUTSTANDING",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Combined balance",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Text(
            "₹${totalOutstandingDebt.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _divider),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: _textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: "Search by student name or ID",
            hintStyle: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _textSecondary,
              size: 21,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: _textSecondary,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilterSection() {
    return SizedBox(
      height: 43,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildFilterChip("All Payments", "All", Icons.grid_view_rounded),
          _buildFilterChip("Current Cycle", "Current", Icons.bolt_rounded),
          _buildFilterChip("Previous Cycle", "Previous", Icons.history_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final selected = selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? _primary : _surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _changeFilter(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: selected ? _primary : _divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : _textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESULT HEADER
  // ---------------------------------------------------------------------------

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Text(
            "Payment Records",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),

          const SizedBox(width: 7),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _softPrimarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              filteredPayments.length.toString(),
              style: TextStyle(
                color: _primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const Spacer(),

          Text(
            selectedFilter == "All" ? "All" : selectedFilter,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAYMENT CARD
  // ---------------------------------------------------------------------------

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final student = payment['studentId'] ?? {};

    final String name = student['name']?.toString() ?? "Unknown Student";

    final String photoUrl = student['photoURL']?.toString() ?? "";

    final String title = payment['title']?.toString() ?? "Payment Invoice";

    final String amount = _getAmount(payment['amount']).toStringAsFixed(0);

    final String screenshotUrl = payment['paymentScreenshot']?.toString() ?? "";

    final String month = payment['month']?.toString() ?? "";

    final String cycleDetails = payment['cycleDescription']?.toString() ?? "";

    final bool previous = _isPreviousCycle(payment);

    final String status = _getStatus(payment);

    final bool paid = status == 'success';

    final bool isProcess = status == 'processing';

    final PaymentVisual visual = _getPaymentVisual(
      status: status,
      previous: previous,
    );

    final String date = _formatDate(payment['date']);

    final String studentId =
        student['registrationNumber']?.toString() ??
        student['_id']?.toString() ??
        "";

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (screenshotUrl.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentScreenshotScreen(
                  imageUrl: screenshotUrl,
                  studentName: name,
                ),
              ),
            );
          } else {
            _showMessage("No verification screenshot uploaded for this bill.");
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: visual.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.18 : 0.025),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Status stripe
                  Container(width: 5, color: visual.color),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAvatar(
                                name: name,
                                photoUrl: photoUrl,
                                color: visual.color,
                              ),

                              const SizedBox(width: 11),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 7),

                                        _buildCycleBadge(previous, month),
                                      ],
                                    ),

                                    if (studentId.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        studentId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: _textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 13),

                          // Invoice details
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                      ),
                                    ),

                                    if (cycleDetails.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        cycleDetails,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: previous ? danger : _primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              Text(
                                "₹$amount",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: visual.color,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: _textSecondary,
                              ),

                              const SizedBox(width: 4),

                              Expanded(
                                child: Text(
                                  date,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              _buildStatusBadge(visual, status),
                            ],
                          ),

                          if (screenshotUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildReceiptHint(
                              paid: paid,
                              processing: isProcess,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AVATAR
  // ---------------------------------------------------------------------------

  Widget _buildAvatar({
    required String name,
    required String photoUrl,
    required Color color,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _buildInitial(name, color);
                },
              )
            : _buildInitial(name, color),
      ),
    );
  }

  Widget _buildInitial(String name, Color color) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CYCLE BADGE
  // ---------------------------------------------------------------------------

  Widget _buildCycleBadge(bool previous, String month) {
    final color = previous ? danger : _primary;

    final label = previous
        ? (month.isNotEmpty ? month.toUpperCase() : "PREVIOUS")
        : "CURRENT";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS BADGE
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge(PaymentVisual visual, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: visual.lightColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12, color: visual.color),
          const SizedBox(width: 4),
          Text(
            visual.label,
            style: TextStyle(
              color: visual.color,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECEIPT HINT
  // ---------------------------------------------------------------------------

  Widget _buildReceiptHint({required bool paid, required bool processing}) {
    Color receiptColor;

    if (paid) {
      receiptColor = _StudentPaymentScreenState.success;
    } else if (processing) {
      receiptColor = _StudentPaymentScreenState.processing;
    } else {
      receiptColor = _primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: receiptColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 14, color: receiptColor),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              "Verification receipt available • Tap to view",
              style: TextStyle(
                fontSize: 9.5,
                color: receiptColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: receiptColor),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISUAL STATUS
  // ---------------------------------------------------------------------------

  PaymentVisual _getPaymentVisual({
    required String status,
    required bool previous,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (status == 'success') {
      return PaymentVisual(
        color: success,
        lightColor: isDark ? const Color(0xFF173527) : const Color(0xFFF0FDF4),
        borderColor: isDark ? const Color(0xFF28583E) : const Color(0xFFD1FAE5),
        icon: Icons.check_circle_rounded,
        label: "PAID",
      );
    }

    if (status == 'processing') {
      return PaymentVisual(
        color: processing,
        lightColor: isDark ? const Color(0xFF19294B) : const Color(0xFFEFF6FF),
        borderColor: isDark ? const Color(0xFF2D4778) : const Color(0xFFDBEAFE),
        icon: Icons.hourglass_top_rounded,
        label: "PROCESSING",
      );
    }

    if (status == 'rejected') {
      return PaymentVisual(
        color: danger,
        lightColor: isDark ? const Color(0xFF351C23) : const Color(0xFFFEF2F2),
        borderColor: isDark ? const Color(0xFF63303B) : const Color(0xFFFECACA),
        icon: Icons.cancel_outlined,
        label: "REJECTED",
      );
    }

    if (previous) {
      return PaymentVisual(
        color: danger,
        lightColor: isDark ? const Color(0xFF351C23) : const Color(0xFFFFF1F2),
        borderColor: isDark ? const Color(0xFF63303B) : const Color(0xFFFECACA),
        icon: Icons.warning_amber_rounded,
        label: "OVERDUE",
      );
    }

    return PaymentVisual(
      color: warning,
      lightColor: isDark ? const Color(0xFF382B18) : const Color(0xFFFFFBEB),
      borderColor: isDark ? const Color(0xFF5D4724) : const Color(0xFFFDE68A),
      icon: Icons.pending_actions_rounded,
      label: "PENDING",
    );
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------

  String _formatDate(dynamic value) {
    if (value == null) {
      return "Date unavailable";
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: _softPrimarySurface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: _primary,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              hasSearch ? "No matching payments" : "No payment records",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              hasSearch
                  ? "Try another student name or registration ID."
                  : "Payment records will appear here once available.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: _textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            if (hasSearch)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: Icon(Icons.clear_rounded, size: 17, color: _primary),
                label: Text("Clear Search", style: TextStyle(color: _primary)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: BorderSide(color: _primary.withOpacity(0.25)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LOADING STATE
// =============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF292650) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            "Loading payment records...",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAYMENT VISUAL MODEL
// =============================================================================

class PaymentVisual {
  final Color color;
  final Color lightColor;
  final Color borderColor;
  final IconData icon;
  final String label;

  const PaymentVisual({
    required this.color,
    required this.lightColor,
    required this.borderColor,
    required this.icon,
    required this.label,
  });
}

// =============================================================================
// PAYMENT SCREENSHOT
// =============================================================================

class PaymentScreenshotScreen extends StatelessWidget {
  final String imageUrl;
  final String studentName;

  const PaymentScreenshotScreen({
    super.key,
    required this.imageUrl,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "$studentName's Receipt",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: imageUrl.isNotEmpty
            ? InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Failed to load receipt",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No receipt uploaded",
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}
