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

  final TextEditingController _studentSearchController =
      TextEditingController();

  String _studentSearchQuery = '';

  // ============================================================
  // THEME-AWARE DESIGN SYSTEM
  // ============================================================

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _primaryDark => const Color(0xFF3F35A8);

  Color get _primarySoft => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF292650)
      : const Color(0xFFEEEEFF);

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _border => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2C303A)
      : const Color(0xFFE7E7EF);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Semantic colors intentionally remain stable.
  static const Color green = Color(0xFF16A05D);

  Color get _greenSoft =>
      _isDark ? const Color(0xFF173527) : const Color(0xFFEAF9F1);

  static const Color orange = Color(0xFFF29A24);

  Color get _orangeSoft =>
      _isDark ? const Color(0xFF382B18) : const Color(0xFFFFF4E4);

  static const Color blue = Color(0xFF3D6EFF);

  Color get _blueSoft =>
      _isDark ? const Color(0xFF19294B) : const Color(0xFFEDF2FF);

  static const Color red = Color(0xFFE94C5F);

  Color get _redSoft =>
      _isDark ? const Color(0xFF381D24) : const Color(0xFFFFEEF1);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _controller.initialize(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _formatMoney(dynamic value) {
    return '₹$value';
  }

  // ============================================================
  // STUDENT SEARCH
  // ============================================================

  void _clearStudentSearch() {
    _studentSearchController.clear();

    setState(() {
      _studentSearchQuery = '';
    });
  }

  List<dynamic> _getFilteredStudents() {
    final students = _controller.studentUsageList;

    if (_studentSearchQuery.trim().isEmpty) {
      return students;
    }

    final query = _studentSearchQuery.trim().toLowerCase();

    return students.where((student) {
      final name = student['name']?.toString().toLowerCase() ?? '';

      final email = student['email']?.toString().toLowerCase() ?? '';

      final title = student['title']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          email.contains(query) ||
          title.contains(query);
    }).toList();
  }

  // ============================================================
  // RECEIPT
  // ============================================================

  void _viewReceiptImageDialog(String studentName, String imgUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);

        return Dialog(
          backgroundColor: dialogTheme.dialogBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _primarySoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: _primary,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Receipt',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: dialogTheme.colorScheme.onSurface,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              studentName,
                              style: TextStyle(
                                fontSize: 11,
                                color: dialogTheme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: _background,
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return SizedBox(
                              height: 300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: _primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 70,
                                horizontal: 30,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 48,
                                    color: _textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Unable to display receipt',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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

  // ============================================================
  // CYCLE SELECTION
  // ============================================================

  void _showDateSelectionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bc) {
        final sheetTheme = Theme.of(bc);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          decoration: BoxDecoration(
            color: sheetTheme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sheetTheme.dividerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.timeline_rounded, color: _primary),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analysis Period',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Choose the financial window',
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _controller.calculatedCyclesList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 44,
                              color: _textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No analysis cycles found',
                              style: TextStyle(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _controller.calculatedCyclesList.length,
                        itemBuilder: (context, index) {
                          final cycle = _controller.calculatedCyclesList[index];

                          final bool isLive = cycle['isCurrentActive'] == true;

                          return _cycleTile(cycle, isLive, bc);
                        },
                      ),
              ),

              const SizedBox(height: 10),

              _customRangeTile(bc),
            ],
          ),
        );
      },
    );
  }

  Widget _cycleTile(dynamic cycle, bool isLive, BuildContext bc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isLive ? _primarySoft : _background,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isLive ? _primary.withOpacity(0.18) : _border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isLive ? _primary : _surface,
            borderRadius: BorderRadius.circular(13),
            border: isLive ? null : Border.all(color: _border),
          ),
          child: Icon(
            isLive ? Icons.bolt_rounded : Icons.history_rounded,
            color: isLive ? Colors.white : _textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          cycle['label'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isLive ? _primary : _textPrimary,
          ),
        ),
        subtitle: Text(
          isLive
              ? 'Currently active analysis period'
              : 'Historical financial period',
          style: TextStyle(fontSize: 10, color: _textSecondary),
        ),
        trailing: isLive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _textSecondary,
              ),
        onTap: () {
          Navigator.pop(bc);

          _controller.selectCycle(cycle, () {
            if (mounted) {
              setState(() {});
            }
          }, _showErrorSnackBar);
        },
      ),
    );
  }

  Widget _customRangeTile(BuildContext bc) {
    return Column(
      children: [
        Divider(height: 20, color: _dividerColor()),
        InkWell(
          onTap: () {
            Navigator.pop(bc);
            _showNativeDatePicker(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: blue.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.date_range_rounded,
                    color: blue,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Date Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Define your own analysis boundaries',
                        style: TextStyle(fontSize: 10, color: _textSecondary),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _dividerColor() {
    return Theme.of(context).dividerColor;
  }

  Future<void> _showNativeDatePicker(BuildContext context) async {
    final DateTime todayMidnight = DateTime(
      _controller.lastAvailableMealDate.year,
      _controller.lastAvailableMealDate.month,
      _controller.lastAvailableMealDate.day,
    );

    final DateTime safeStart = _controller.startDate.isAfter(todayMidnight)
        ? todayMidnight
        : _controller.startDate;

    final DateTime safeEnd = _controller.endDate.isAfter(todayMidnight)
        ? todayMidnight
        : _controller.endDate;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: _controller.firstAvailableMealDate,
      lastDate: todayMidnight,
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      helpText: 'SELECT ANALYSIS PERIOD',
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _controller.selectCustomRange(picked, () {
        if (mounted) {
          setState(() {});
        }
      }, _showErrorSnackBar);
    }
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Track hostel finances & operations',
              style: TextStyle(
                fontSize: 10,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Generate PDF Report',
            onPressed: _controller.exportToPdf,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _redSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: red,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: _controller.isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
            )
          : NestedScrollView(
              physics: const BouncingScrollPhysics(),

              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(child: _buildPeriodHeader()),
                      SliverToBoxAdapter(child: _buildCycleBanner()),
                      SliverToBoxAdapter(child: _buildFinancialOverview()),
                      SliverToBoxAdapter(child: _buildTabs()),
                    ];
                  },

              body: TabBarView(
                controller: _tabController,
                children: [_buildStudentUsageTab(), _buildProcurementTab()],
              ),
            ),
    );
  }

  // ============================================================
  // PERIOD HEADER
  // ============================================================

  Widget _buildPeriodHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: InkWell(
        onTap: () => _showDateSelectionOptions(context),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANALYSIS PERIOD',
                      style: TextStyle(
                        fontSize: 9,
                        color: _textSecondary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${DateFormat('dd MMM yyyy').format(_controller.startDate)}  →  ${DateFormat('dd MMM yyyy').format(_controller.endDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CURRENT CYCLE
  // ============================================================

  Widget _buildCycleBanner() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: _orangeSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: orange.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: orange, size: 19),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT FOCUS',
                    style: TextStyle(
                      fontSize: 8,
                      color: _textSecondary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'Active Operational Cycle',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            Text(
              '#${_controller.currentActiveCycleNumber}',
              style: const TextStyle(
                fontSize: 17,
                color: orange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FINANCIAL OVERVIEW
  // ============================================================

  Widget _buildFinancialOverview() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary, _primaryDark],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Text(
                    'NET BALANCE',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                Text(
                  _formatMoney(_controller.netBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'INFLOW',
                  value: _formatMoney(_controller.totalCollections),
                  icon: Icons.arrow_downward_rounded,
                  color: green,
                  softColor: _greenSoft,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _metricCard(
                  title: 'EXPENSE',
                  value: _formatMoney(_controller.totalExpenses),
                  icon: Icons.arrow_upward_rounded,
                  color: orange,
                  softColor: _orangeSoft,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'MEALS SERVED',
                  value: '${_controller.totalMealsServed}',
                  icon: Icons.restaurant_rounded,
                  color: blue,
                  softColor: _blueSoft,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _metricCard(
                  title: 'FINANCIAL STATUS',
                  value: _controller.netBalance >= 0 ? 'POSITIVE' : 'NEGATIVE',
                  icon: _controller.netBalance >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: _controller.netBalance >= 0 ? green : red,
                  softColor: _controller.netBalance >= 0
                      ? _greenSoft
                      : _redSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color softColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _surface, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    color: color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildTabs() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.22 : 0.06),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _primary,
          unselectedLabelColor: _textSecondary,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.people_alt_outlined, size: 17),
              text: 'Student Ledgers',
            ),
            Tab(
              icon: Icon(Icons.shopping_bag_outlined, size: 17),
              text: 'Procurements',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildStudentSearchBar(int totalStudents, int filteredStudents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.16 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _studentSearchController,
            onChanged: (value) {
              setState(() {
                _studentSearchQuery = value.trim().toLowerCase();
              });
            },
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 13,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search student by name or email...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.search_rounded, color: _primary, size: 20),
              ),
              suffixIcon: _studentSearchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearStudentSearch,
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _textSecondary,
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 16,
              ),
            ),
          ),
        ),

        if (_studentSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 5),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$filteredStudents found',
                    style: TextStyle(
                      fontSize: 9,
                      color: _primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  'of $totalStudents students',
                  style: TextStyle(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ============================================================
  // STUDENT LEDGER
  // ============================================================

  Widget _buildStudentUsageTab() {
    if (_controller.studentUsageList.isEmpty) {
      return _emptyState(
        icon: Icons.people_outline_rounded,
        title: 'No Student Records',
        subtitle: 'No student financial records were found for this period.',
      );
    }

    final List<dynamic> students = _getFilteredStudents();

    return CustomScrollView(
      key: const PageStorageKey<String>('student-ledgers'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildStudentSearchBar(
            _controller.studentUsageList.length,
            students.length,
          ),
        ),

        if (students.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(
              icon: Icons.person_search_rounded,
              title: 'No Students Found',
              subtitle: 'Try searching with another student name or email.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 30),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final student = students[index];

                final bool isPaid = student['status'] == 'success';

                final String? receiptUrl = student['paymentScreenshot'];

                final String? photoUrl = student['photoURL'];

                return _studentCard(student, isPaid, receiptUrl, photoUrl);
              }, childCount: students.length),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget _studentCard(
    dynamic student,
    bool isPaid,
    String? receiptUrl,
    String? photoUrl,
  ) {
    final String status = student['status']?.toString().toLowerCase() ?? '';

    final Color statusColor = isPaid
        ? green
        : status == 'processing'
        ? blue
        : orange;

    final Color statusSoft = isPaid
        ? _greenSoft
        : status == 'processing'
        ? _blueSoft
        : _orangeSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: _primarySoft,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Icon(Icons.person_rounded, color: _primary, size: 25)
                    : null,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name']?.toString() ?? 'Unknown Student',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      student['title']?.toString() ??
                          student['email']?.toString() ??
                          'No email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMoney(student['amount']),
                    style: TextStyle(
                      fontSize: 16,
                      color: _textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 5),

                  _statusBadge(
                    isPaid ? 'PAID' : status.toUpperCase(),
                    statusColor,
                    statusSoft,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 13),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_outlined, size: 17, color: blue),

                const SizedBox(width: 7),

                Expanded(
                  child: Text(
                    'Consumed: ${student['consumed']} meals',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if (isPaid && receiptUrl != null && receiptUrl.isNotEmpty)
                  InkWell(
                    onTap: () => _viewReceiptImageDialog(
                      student['name']?.toString() ?? 'Student',
                      receiptUrl,
                    ),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primarySoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 14,
                            color: _primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Receipt',
                            style: TextStyle(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(String text, Color color, Color softColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ============================================================
  // PROCUREMENT
  // ============================================================

  Widget _buildProcurementTab() {
    if (_controller.expenseItemsList.isEmpty) {
      return _emptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No Procurement Records',
        subtitle: 'No procurement activity was found for this period.',
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('procurements'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final expense = _controller.expenseItemsList[index];

              return _procurementCard(expense);
            }, childCount: _controller.expenseItemsList.length),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROCUREMENT CARD
  // ============================================================

  Widget _procurementCard(dynamic expense) {
    final bool isBought = expense['isBought'] == true;

    final Color color = isBought ? orange : _textSecondary;

    final Color softColor = isBought ? _orangeSoft : _background;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isBought
                  ? Icons.shopping_bag_rounded
                  : Icons.shopping_basket_outlined,
              color: color,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expense['name']?.toString() ?? 'Unnamed Item',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      _formatMoney(expense['price']),
                      style: TextStyle(
                        fontSize: 15,
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                if (expense['description'] != null &&
                    expense['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense['description'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    _smallMeta(
                      Icons.person_outline_rounded,
                      expense['createdBy'] ?? 'Manager',
                    ),

                    const SizedBox(width: 12),

                    _smallMeta(
                      Icons.calendar_today_outlined,
                      expense['dateTime'] ?? 'N/A',
                    ),

                    const Spacer(),

                    _statusBadge(
                      isBought ? 'BOUGHT' : 'CART LIST',
                      color,
                      softColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL META
  // ============================================================

  Widget _smallMeta(IconData icon, dynamic text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _textSecondary),

          const SizedBox(width: 4),

          Flexible(
            child: Text(
              text.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: _primary),
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
