import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/views/utility_screen/financials_page.dart';
import '../../utility_screen/meal_packages_section.dart';

class MyVotesPage extends StatefulWidget {
  const MyVotesPage({super.key});

  @override
  State<MyVotesPage> createState() => _MyVotesPageState();
}

class _MyVotesPageState extends State<MyVotesPage> {
  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color _primary = Color(0xFF5B4FE9);
  static const Color _primaryDark = Color(0xFF4338CA);

  static const Color _background = Color(0xFFF7F8FC);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);
  static const Color _orange = Color(0xFFD97706);
  static const Color _blue = Color(0xFF2563EB);

  // ===========================================================================
  // SERVICES
  // ===========================================================================

  final ApiService api = ApiService();

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<dynamic> guestRequests = [];

  Map<String, dynamic>? activeSubscription;

  String? activePackageId;

  bool isLoading = true;

  double pendingDues = 0;

  List<String> availableDates = [];

  // ===========================================================================
  // MEAL USAGE
  // ===========================================================================

  int chickenUsed = 0;
  int chickenMax = 0;

  int fishUsed = 0;
  int fishMax = 0;

  int paneerUsed = 0;
  int paneerMax = 0;

  int muttonUsed = 0;
  int muttonMax = 0;

  int eggUsed = 0;
  int eggMax = 0;

  int vegUsed = 0;
  int vegMax = 0;

  int totalUsed = 0;
  int totalLimit = 0;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ===========================================================================
  // DATA LOADING
  // ===========================================================================

  Future<void> _loadAllData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final results = await Future.wait([
        api.getVoteSummary(),
        api.getMyFines(),
        api.getMyGuestMealRequests(),
      ]);

      final Map<String, dynamic> subscriptionResponse =
          results[0] is Map<String, dynamic>
          ? results[0] as Map<String, dynamic>
          : {};

      final List<dynamic> fines = results[1] is List ? results[1] as List : [];

      final List<dynamic> requests = results[2] is List
          ? results[2] as List
          : [];

      // -----------------------------------------------------------------------
      // CALCULATE DUES
      // -----------------------------------------------------------------------

      double calculatedDues = 0;

      for (final item in fines) {
        if (item is! Map) continue;

        final String status = item['status']?.toString().toLowerCase() ?? '';

        if (status == 'pending' || status == 'rejected') {
          calculatedDues += _toDouble(item['amount']);
        }
      }

      // -----------------------------------------------------------------------
      // FIND ACTIVE SUBSCRIPTION
      // -----------------------------------------------------------------------

      Map<String, dynamic>? subscription;

      final dynamic rawData = subscriptionResponse['data'];

      if (subscriptionResponse['success'] == true &&
          rawData is List &&
          rawData.isNotEmpty) {
        final List<dynamic> subscriptions = rawData;

        dynamic selected;

        try {
          selected = subscriptions.firstWhere((item) {
            if (item is! Map) return false;

            return item['status']?.toString().toLowerCase() != 'completed';
          });
        } catch (_) {
          selected = subscriptions.first;
        }

        if (selected is Map) {
          subscription = Map<String, dynamic>.from(selected);
        }
      }

      if (!mounted) return;

      setState(() {
        activeSubscription = subscription;

        if (subscription != null) {
          activePackageId = subscription['mealsPlanId']?.toString();

          _readSubscriptionUsage(subscription);
        } else {
          _resetUsage();
        }

        pendingDues = calculatedDues;

        guestRequests = requests;

        _buildAvailableDates();

        isLoading = false;
      });
    } catch (e) {
      debugPrint('My Meals loading error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showSnackBar('Unable to load meal information.', error: true);
    }
  }

  // ===========================================================================
  // SUBSCRIPTION USAGE
  // ===========================================================================

  void _readSubscriptionUsage(Map<String, dynamic> subscription) {
    final dynamic rawUsage = subscription['usage'];
    final dynamic rawLimits = subscription['maxLimits'];

    final Map<String, dynamic> usage = rawUsage is Map
        ? Map<String, dynamic>.from(rawUsage)
        : {};

    final Map<String, dynamic> limits = rawLimits is Map
        ? Map<String, dynamic>.from(rawLimits)
        : {};

    chickenUsed = _toInt(usage['chicken']);
    chickenMax = _toInt(limits['chicken']);

    fishUsed = _toInt(usage['fish']);
    fishMax = _toInt(limits['fish']);

    paneerUsed = _toInt(usage['paneer']);
    paneerMax = _toInt(limits['paneer']);

    muttonUsed = _toInt(usage['mutton']);
    muttonMax = _toInt(limits['mutton']);

    eggUsed = _toInt(usage['egg']);
    eggMax = _toInt(limits['egg']);

    vegUsed = _toInt(usage['veg']);
    vegMax = _toInt(limits['veg']);

    totalUsed =
        chickenUsed + fishUsed + paneerUsed + muttonUsed + eggUsed + vegUsed;

    totalLimit = chickenMax + fishMax + paneerMax + muttonMax + eggMax + vegMax;
  }

  void _resetUsage() {
    chickenUsed = 0;
    chickenMax = 0;

    fishUsed = 0;
    fishMax = 0;

    paneerUsed = 0;
    paneerMax = 0;

    muttonUsed = 0;
    muttonMax = 0;

    eggUsed = 0;
    eggMax = 0;

    vegUsed = 0;
    vegMax = 0;

    totalUsed = 0;
    totalLimit = 0;

    activePackageId = null;
  }

  // ===========================================================================
  // SAFE CONVERSION
  // ===========================================================================

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ===========================================================================
  // AVAILABLE DATES
  // ===========================================================================

  void _buildAvailableDates() {
    final DateTime today = DateTime.now();

    availableDates = [
      DateFormat('dd/MM/yyyy').format(today),
      DateFormat('dd/MM/yyyy').format(today.add(const Duration(days: 1))),
    ];
  }

  // ===========================================================================
  // CALCULATED VALUES
  // ===========================================================================

  int get remainingMeals {
    final value = totalLimit - totalUsed;

    return value < 0 ? 0 : value;
  }

  double get usageProgress {
    if (totalLimit <= 0) {
      return 0;
    }

    return (totalUsed / totalLimit).clamp(0.0, 1.0);
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(String message, {bool error = false}) {
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
          backgroundColor: error ? _red : _green,
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 9),
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

  // ===========================================================================
  // LOW MEAL NOTIFICATION
  // ===========================================================================

  Widget _buildMealBalanceNotification() {
    if (remainingMeals > 5) {
      return const SizedBox.shrink();
    }

    final bool exhausted = remainingMeals == 0;

    final Color accent = exhausted ? _red : _orange;

    final Color background = exhausted
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFFFF8EB);

    final Color border = exhausted
        ? const Color(0xFFFECACA)
        : const Color(0xFFFDE68A);

    final String title = exhausted
        ? 'Meal balance exhausted'
        : 'Low meal balance';

    final String message = exhausted
        ? 'You have no meals remaining in your current package.'
        : 'Only $remainingMeals meal${remainingMeals == 1 ? '' : 's'} remaining. Consider planning your next package.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                exhausted
                    ? Icons.no_meals_rounded
                    : Icons.warning_amber_rounded,
                color: accent,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: exhausted
                          ? const Color(0xFF991B1B)
                          : const Color(0xFF92400E),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    message,
                    style: TextStyle(
                      color: exhausted
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFFB45309),
                      fontSize: 10.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 9),

                  Row(
                    children: [
                      Text(
                        '$remainingMeals',
                        style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'MEALS LEFT',
                        style: TextStyle(
                          color: accent,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          backgroundColor: Colors.white,
          onRefresh: _loadAllData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              if (isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LoadingView(),
                )
              else ...[
                // =============================================================
                // LOCAL MEAL BALANCE NOTIFICATION
                // =============================================================
                SliverToBoxAdapter(child: _buildMealBalanceNotification()),

                SliverToBoxAdapter(child: _buildConsumptionCard()),

                SliverToBoxAdapter(child: _buildUsageSection()),

                SliverToBoxAdapter(child: _buildPackageSection()),

                SliverToBoxAdapter(child: _buildGuestSection()),

                SliverToBoxAdapter(child: _buildFinanceSection()),

                SliverToBoxAdapter(child: _buildRequestHistory()),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Meals',
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Track your package and meal consumption',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: _loadAllData,
              child: Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: _muted,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONSUMPTION CARD
  // ===========================================================================

  Widget _buildConsumptionCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CURRENT PACKAGE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    activeSubscription == null ? 'NO PACKAGE' : 'ACTIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(child: _heroMetric('$totalLimit', 'TOTAL MEALS')),

                Container(
                  width: 1,
                  height: 45,
                  color: Colors.white.withOpacity(0.14),
                ),

                Expanded(child: _heroMetric('$totalUsed', 'USED')),

                Container(
                  width: 1,
                  height: 45,
                  color: Colors.white.withOpacity(0.14),
                ),

                Expanded(child: _heroMetric('$remainingMeals', 'REMAINING')),
              ],
            ),

            const SizedBox(height: 21),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Package usage',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(usageProgress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: usageProgress,
                minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // USAGE SECTION
  // ===========================================================================

  Widget _buildUsageSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Meal Breakdown', 'Individual package consumption'),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFEAEAF0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _mealUsageTile(
                        'Chicken',
                        chickenUsed,
                        chickenMax,
                        Icons.kebab_dining_rounded,
                        const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mealUsageTile(
                        'Fish',
                        fishUsed,
                        fishMax,
                        Icons.set_meal_rounded,
                        const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _mealUsageTile(
                        'Paneer',
                        paneerUsed,
                        paneerMax,
                        Icons.grass_rounded,
                        const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mealUsageTile(
                        'Mutton',
                        muttonUsed,
                        muttonMax,
                        Icons.dinner_dining_rounded,
                        const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _mealUsageTile(
                        'Egg',
                        eggUsed,
                        eggMax,
                        Icons.egg_rounded,
                        const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _mealUsageTile(
                        'Veg',
                        vegUsed,
                        vegMax,
                        Icons.grass_rounded,
                        const Color(0xFF16A34A),
                      ),
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

  Widget _mealUsageTile(
    String title,
    int used,
    int maximum,
    IconData icon,
    Color color,
  ) {
    final double progress = maximum <= 0 ? 0 : (used / maximum).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),

              const Spacer(),

              Text(
                '$used/$maximum',
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Text(
            title,
            style: const TextStyle(
              color: _text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PACKAGE SECTION
  // ===========================================================================

  Widget _buildPackageSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionTitle(
              'Meal Packages',
              'Manage your selected package',
            ),
          ),

          const SizedBox(height: 12),

          MealPackagesSection(onActionSuccess: _loadAllData),
        ],
      ),
    );
  }

  // ===========================================================================
  // GUEST SECTION
  // ===========================================================================

  Widget _buildGuestSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Guest Meals', 'Request an additional meal'),

          const SizedBox(height: 12),

          if (pendingDues > 0) _buildGuestBlocked() else _buildGuestAction(),
        ],
      ),
    );
  }

  Widget _buildGuestAction() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: _showGuestMealBottomSheet,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFEAEAF0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: _primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Guest Meal',
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose date, meal time and variation',
                      style: TextStyle(color: _muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),

              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F0FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: _primary,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestBlocked() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: _red,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest requests locked',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Clear your pending dues before requesting a guest meal.',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FINANCE
  // ===========================================================================

  Widget _buildFinanceSection() {
    final bool hasDues = pendingDues > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Financial Status', 'Your current mess account'),

          const SizedBox(height: 12),

          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(21),
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinancialsPage()),
                ).then((_) => _loadAllData());
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: hasDues
                        ? const [Color(0xFFDC2626), Color(0xFF991B1B)]
                        : const [Color(0xFF16A34A), Color(0xFF15803D)],
                  ),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        hasDues
                            ? Icons.account_balance_wallet_rounded
                            : Icons.verified_rounded,
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
                            hasDues ? 'Pending Dues' : 'Account Clear',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            hasDues
                                ? 'Payment required'
                                : 'No outstanding dues',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            '₹${pendingDues.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REQUEST HISTORY
  // ===========================================================================

  Widget _buildRequestHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Guest Meal Activity',
            guestRequests.isEmpty
                ? 'No requests yet'
                : '${guestRequests.length} request${guestRequests.length == 1 ? '' : 's'}',
          ),

          const SizedBox(height: 12),

          if (guestRequests.isEmpty)
            _buildEmptyRequests()
          else
            ...guestRequests.map((request) => _buildGuestRequestCard(request)),
        ],
      ),
    );
  }

  // ===========================================================================
  // GUEST REQUEST CARD
  // ===========================================================================

  Widget _buildGuestRequestCard(dynamic request) {
    if (request is! Map) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(request);

    final int count = _toInt(data['guestCount']) > 0
        ? _toInt(data['guestCount'])
        : 1;

    final String mealDate = data['mealDate']?.toString() ?? 'Date unavailable';

    final String mealTime =
        data['mealTime']?.toString() ?? 'Meal time unavailable';

    final String preference =
        data['guestItemPreference']?.toString() ?? 'regular';

    final String status = data['status']?.toString() ?? 'pending';

    final Color variationColor = _getVariationColor(preference);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: variationColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getVariationIcon(preference),
              color: variationColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Guest${count == 1 ? '' : 's'} • $mealTime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: _muted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        mealDate,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Icon(
                      _getVariationIcon(preference),
                      size: 12,
                      color: variationColor,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        preference.replaceAll('_', ' ').toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: variationColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          _buildStatusBadge(status),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATUS BADGE
  // ===========================================================================

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
      case 'success':
        color = _green;
        icon = Icons.check_circle_rounded;
        break;

      case 'rejected':
        color = _red;
        icon = Icons.cancel_rounded;
        break;

      case 'processing':
        color = _blue;
        icon = Icons.hourglass_top_rounded;
        break;

      default:
        color = _orange;
        icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY REQUESTS
  // ===========================================================================

  Widget _buildEmptyRequests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAEAF0)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _primary,
              size: 23,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'No guest requests yet',
            style: TextStyle(
              color: _text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Your guest meal activity will appear here.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // VARIATION ICON
  // ===========================================================================

  IconData _getVariationIcon(String choice) {
    final String value = choice.toLowerCase();

    if (value.contains('chicken')) {
      return Icons.kebab_dining_rounded;
    }

    if (value.contains('egg')) {
      return Icons.egg_rounded;
    }

    if (value.contains('fish')) {
      return Icons.set_meal_rounded;
    }

    if (value.contains('veg')) {
      return Icons.grass_rounded;
    }

    return Icons.restaurant_rounded;
  }

  // ===========================================================================
  // VARIATION COLOR
  // ===========================================================================

  Color _getVariationColor(String choice) {
    final String value = choice.toLowerCase();

    if (value.contains('chicken')) {
      return const Color(0xFFDC2626);
    }

    if (value.contains('egg')) {
      return const Color(0xFFD97706);
    }

    if (value.contains('fish')) {
      return const Color(0xFF2563EB);
    }

    if (value.contains('veg')) {
      return const Color(0xFF16A34A);
    }

    return _primary;
  }

  // ===========================================================================
  // GUEST MEAL BOTTOM SHEET
  // ===========================================================================

  void _showGuestMealBottomSheet() {
    String selectedDate = availableDates.isNotEmpty ? availableDates.first : '';

    String selectedTime = 'Morning';

    String selectedPreference = 'regular';

    int guestCount = 1;

    bool checking = false;
    bool available = false;
    String menuName = '';

    Future<void> checkAvailability(StateSetter setModalState) async {
      if (selectedDate.isEmpty) {
        return;
      }

      setModalState(() {
        checking = true;
        available = false;
        menuName = '';
      });

      try {
        final response = await api.getDetailedVotesByDate(
          selectedDate,
          selectedTime,
        );

        bool mealExists = false;
        String detectedMenu = 'CONFIGURED ROUTINE';

        if (response['success'] == true) {
          mealExists = true;
        }

        final dynamic data = response['data'];

        if (data is List && data.isNotEmpty) {
          mealExists = true;

          final dynamic first = data.first;

          if (first is Map) {
            detectedMenu =
                first['menuItem']?.toString().toUpperCase() ?? 'MEAL';
          }
        }

        if (!mounted) return;

        setModalState(() {
          checking = false;
          available = mealExists;

          if (mealExists) {
            menuName = detectedMenu;
          }
        });
      } catch (e) {
        if (!mounted) return;

        setModalState(() {
          checking = false;
          available = false;
          menuName = '';
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            if (!checking && !available && menuName.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (modalContext.mounted) {
                  checkAvailability(setModalState);
                }
              });
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    MediaQuery.of(modalContext).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primary, _primaryDark],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),

                          const SizedBox(width: 12),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guest Meal',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Create a guest meal request',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _modalLabel('MEAL DATE'),

                      const SizedBox(height: 8),

                      _dropdownContainer(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedDate.isNotEmpty
                                ? selectedDate
                                : null,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: availableDates
                                .map(
                                  (date) => DropdownMenuItem<String>(
                                    value: date,
                                    child: Text(
                                      date,
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setModalState(() {
                                selectedDate = value;
                                available = false;
                                menuName = '';
                              });

                              checkAvailability(setModalState);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 19),

                      _modalLabel('MEAL TIME'),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _timeOption(
                              label: 'Morning',
                              icon: Icons.wb_sunny_rounded,
                              selected: selectedTime == 'Morning',
                              color: _orange,
                              onTap: () {
                                setModalState(() {
                                  selectedTime = 'Morning';
                                  available = false;
                                  menuName = '';
                                });

                                checkAvailability(setModalState);
                              },
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: _timeOption(
                              label: 'Night',
                              icon: Icons.nightlight_round,
                              selected: selectedTime == 'Night',
                              color: _primary,
                              onTap: () {
                                setModalState(() {
                                  selectedTime = 'Night';
                                  available = false;
                                  menuName = '';
                                });

                                checkAvailability(setModalState);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      if (checking)
                        _checkingCard()
                      else if (!available)
                        _unavailableCard(selectedDate, selectedTime)
                      else ...[
                        _availableCard(menuName, selectedTime),

                        const SizedBox(height: 20),

                        _modalLabel('MEAL VARIATION'),

                        const SizedBox(height: 8),

                        _dropdownContainer(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedPreference,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'regular',
                                  child: Text('Regular — Follows Routine Menu'),
                                ),
                                DropdownMenuItem(
                                  value: 'halal_chicken',
                                  child: Text('Halal Chicken Package'),
                                ),
                                DropdownMenuItem(
                                  value: 'egg_substitute',
                                  child: Text('Egg Substitute alternative'),
                                ),
                                DropdownMenuItem(
                                  value: 'veg_forced',
                                  child: Text('Forced Vegetarian Alternative'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() {
                                    selectedPreference = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        _modalLabel('GUEST COUNT'),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: guestCount > 1
                                    ? () {
                                        setModalState(() => guestCount--);
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: _primary,
                              ),

                              Expanded(
                                child: Text(
                                  '$guestCount Guest${guestCount == 1 ? '' : 's'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),

                              IconButton(
                                onPressed: () {
                                  setModalState(() => guestCount++);
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                color: _primary,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: available
                                ? _primary
                                : const Color(0xFFD1D5DB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: (!available || checking)
                              ? null
                              : () async {
                                  final response = await api.requestGuestMeal(
                                    guestCount: guestCount,
                                    mealDate: selectedDate,
                                    mealTime: selectedTime,
                                    guestItemPreference: selectedPreference,
                                  );

                                  if (!modalContext.mounted) {
                                    return;
                                  }

                                  Navigator.pop(modalContext);

                                  if (response['success'] == true) {
                                    _showSnackBar(
                                      response['message']?.toString() ??
                                          'Guest meal request sent successfully.',
                                    );

                                    await _loadAllData();
                                  } else {
                                    _showErrorDialog(
                                      response['message']?.toString() ??
                                          'Request failed.',
                                    );
                                  }
                                },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                available
                                    ? 'CONFIRM REQUEST'
                                    : 'MEAL NOT AVAILABLE',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // MODAL HELPERS
  // ===========================================================================

  Widget _modalLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _dropdownContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _timeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color.withOpacity(0.10) : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : _muted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(strokeWidth: 2.3, color: _primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Checking meal availability...',
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unavailableCard(String date, String time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_busy_rounded, color: _red, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meal unavailable',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$time meal is not configured for $date.',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _availableCard(String menu, String time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_rounded, color: _green, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meal available',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$time • $menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR DIALOG
  // ===========================================================================

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Request Denied',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// LOADING VIEW
// ==============================================================================

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF5B4FE9),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Loading your meals...',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
