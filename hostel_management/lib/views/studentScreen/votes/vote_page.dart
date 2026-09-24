import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VotePage extends StatefulWidget {
  final String date;
  final String id;
  final Map<String, dynamic> morning;
  final Map<String, dynamic> night;

  const VotePage({
    super.key,
    required this.id,
    required this.date,
    required this.morning,
    required this.night,
  });

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primary = Color(0xFF5B4FE9);
  static const Color primaryDark = Color(0xFF4338CA);

  static const Color background = Color(0xFFF7F8FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  // ===========================================================================
  // API
  // ===========================================================================

  final ApiService api = ApiService();

  // ===========================================================================
  // DATE
  // ===========================================================================

  late DateTime selectedDate;

  // ===========================================================================
  // MEALS
  // ===========================================================================

  late Map<String, dynamic> morningMeal;
  late Map<String, dynamic> nightMeal;

  String morningMealId = '';
  String nightMealId = '';

  bool isLoadingMeals = false;
  bool isInitialLoading = true;
  bool isActionLoading = false;

  String? processingSlot;

  // ===========================================================================
  // VOTE STATE
  // ===========================================================================

  final Map<String, bool> userVotes = {'morning': false, 'night': false};

  final Map<String, String> activeSavedChoices = {'morning': '', 'night': ''};

  final Map<String, String> selectedPreferences = {
    'morning': 'regular',
    'night': 'regular',
  };

  // ===========================================================================
  // VOTING ACCESS
  // ===========================================================================

  bool isCheckingVotingAccess = true;
  bool canUserVote = false;
  String userRole = 'student';

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    selectedDate = _parseDate(widget.date);

    morningMeal = Map<String, dynamic>.from(widget.morning);
    nightMeal = Map<String, dynamic>.from(widget.night);

    morningMealId = _extractMealId(morningMeal) ?? widget.id;
    nightMealId = _extractMealId(nightMeal) ?? widget.id;

    _initialize();
  }

  Future<void> _initialize() async {
    await _checkVotingAccess();

    if (!mounted) return;

    await _fetchCurrentStatus();

    if (!mounted) return;

    setState(() {
      isInitialLoading = false;
    });
  }

  // ===========================================================================
  // VOTING ACCESS
  // ===========================================================================

  Future<void> _checkVotingAccess() async {
    if (!mounted) return;

    setState(() {
      isCheckingVotingAccess = true;
      canUserVote = false;
    });

    try {
      final profileResponse = await api.getProfile();

      String role = _extractRole(profileResponse);

      if (role.isEmpty) {
        role = 'student';
      }

      userRole = role;

      debugPrint('VOTE PAGE → ROLE: $userRole');

      // Manager / Admin can always vote.
      if (_isPrivilegedUser()) {
        if (!mounted) return;

        setState(() {
          canUserVote = true;
          isCheckingVotingAccess = false;
        });

        return;
      }

      // Student → active meal pack required.
      final bool hasPack = await _hasActiveMealPack();

      if (!mounted) return;

      setState(() {
        canUserVote = hasPack;
        isCheckingVotingAccess = false;
      });

      debugPrint('VOTE PAGE → STUDENT MEAL PACK: $hasPack');
    } catch (e) {
      debugPrint('Voting access check error: $e');

      if (!mounted) return;

      setState(() {
        canUserVote = false;
        isCheckingVotingAccess = false;
      });
    }
  }

  String _extractRole(dynamic response) {
    if (response is! Map) {
      return '';
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(response);

    dynamic role = data['role'];

    if (role != null) {
      final value = role.toString().trim().toLowerCase();

      if (value.isNotEmpty && value != 'null') {
        return value;
      }
    }

    dynamic user = data['user'];

    if (user is Map) {
      role = user['role'];

      if (role != null) {
        final value = role.toString().trim().toLowerCase();

        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    dynamic profile = data['profile'];

    if (profile is Map) {
      role = profile['role'];

      if (role != null) {
        final value = role.toString().trim().toLowerCase();

        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    dynamic nestedData = data['data'];

    if (nestedData is Map) {
      role = nestedData['role'];

      if (role != null) {
        final value = role.toString().trim().toLowerCase();

        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }

      final nestedUser = nestedData['user'];

      if (nestedUser is Map) {
        role = nestedUser['role'];

        if (role != null) {
          final value = role.toString().trim().toLowerCase();

          if (value.isNotEmpty && value != 'null') {
            return value;
          }
        }
      }
    }

    return '';
  }

  bool _isPrivilegedUser() {
    return userRole == 'admin' ||
        userRole == 'manager' ||
        userRole == 'admin_manager';
  }

  Future<bool> _hasActiveMealPack() async {
    try {
      final response = await api.getmealPackages();

      debugPrint('VOTE PAGE → PACKAGE RESPONSE: $response');

      if (response['success'] == true) {
        final activePackageId = response['activePackageId'];

        if (activePackageId != null &&
            activePackageId.toString().trim().isNotEmpty &&
            activePackageId.toString().trim().toLowerCase() != 'null') {
          return true;
        }

        final dynamic data = response['data'];

        if (data is Map) {
          final dynamic activeId =
              data['activePackageId'] ??
              data['activeMealPackageId'] ??
              data['packageId'];

          if (activeId != null &&
              activeId.toString().trim().isNotEmpty &&
              activeId.toString().trim().toLowerCase() != 'null') {
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('getmealPackages error: $e');
    }

    // Fallback to subscription information.
    try {
      final response = await api.getVoteSummary();

      debugPrint('VOTE PAGE → SUBSCRIPTION RESPONSE: $response');

      if (response['success'] != true) {
        return false;
      }

      final dynamic data = response['data'];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) continue;

          if (_subscriptionIsActive(item)) {
            return true;
          }
        }
      }

      if (data is Map) {
        return _subscriptionIsActive(data);
      }
    } catch (e) {
      debugPrint('getVoteSummary error: $e');
    }

    return false;
  }

  bool _subscriptionIsActive(Map item) {
    final String status = item['status']?.toString().trim().toLowerCase() ?? '';

    final dynamic planId =
        item['mealsPlanId'] ??
        item['mealPlanId'] ??
        item['packageId'] ??
        item['activePackageId'];

    if (planId == null) {
      return false;
    }

    final String id = planId.toString().trim();

    if (id.isEmpty || id.toLowerCase() == 'null') {
      return false;
    }

    return status != 'completed' &&
        status != 'cancelled' &&
        status != 'expired';
  }

  Future<bool> _canVoteNow() async {
    if (_isPrivilegedUser()) {
      return true;
    }

    return await _hasActiveMealPack();
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

  DateTime _parseDate(String value) {
    try {
      return DateFormat('dd/MM/yyyy').parse(value);
    } catch (_) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String get prettyDate {
    return DateFormat('EEE, dd MMM yyyy').format(selectedDate);
  }

  // ===========================================================================
  // FETCH CURRENT STATUS
  // ===========================================================================

  Future<void> _fetchCurrentStatus() async {
    try {
      final List<Future<Map<String, dynamic>>> calls = [];

      if (morningMealId.isNotEmpty) {
        calls.add(api.checkVoteStatus(morningMealId));
      }

      if (nightMealId.isNotEmpty && nightMealId != morningMealId) {
        calls.add(api.checkVoteStatus(nightMealId));
      }

      if (calls.isEmpty) return;

      final results = await Future.wait(calls);

      if (!mounted) return;

      userVotes['morning'] = false;
      userVotes['night'] = false;

      activeSavedChoices['morning'] = '';
      activeSavedChoices['night'] = '';

      for (final response in results) {
        if (response['success'] != true) {
          continue;
        }

        final dynamic status = response['status'];

        if (status is! Map) {
          continue;
        }

        final Map<String, dynamic> voteStatus = Map<String, dynamic>.from(
          status,
        );

        if (voteStatus.containsKey('morning')) {
          userVotes['morning'] = voteStatus['morning'] == true;

          activeSavedChoices['morning'] =
              voteStatus['morningChoice']?.toString() ?? '';

          selectedPreferences['morning'] = _convertSavedChoice(
            activeSavedChoices['morning']!,
            morningMeal,
          );
        }

        if (voteStatus.containsKey('night')) {
          userVotes['night'] = voteStatus['night'] == true;

          activeSavedChoices['night'] =
              voteStatus['nightChoice']?.toString() ?? '';

          selectedPreferences['night'] = _convertSavedChoice(
            activeSavedChoices['night']!,
            nightMeal,
          );
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('Vote status error: $e');

      if (mounted) {
        _showSnackBar('Failed to load vote status', danger);
      }
    }
  }

  // ===========================================================================
  // LOAD MEALS FOR DATE
  // ===========================================================================

  Future<void> _loadMealsForDate(DateTime date) async {
    if (!mounted) return;

    setState(() {
      isLoadingMeals = true;

      userVotes['morning'] = false;
      userVotes['night'] = false;

      activeSavedChoices['morning'] = '';
      activeSavedChoices['night'] = '';

      selectedPreferences['morning'] = 'regular';
      selectedPreferences['night'] = 'regular';
    });

    final String dateString = DateFormat('dd/MM/yyyy').format(date);

    try {
      final results = await Future.wait([
        api.getDetailedVotesByDate(dateString, 'Morning'),
        api.getDetailedVotesByDate(dateString, 'Night'),
      ]);

      if (!mounted) return;

      final morning = _extractMealFromResponse(results[0]);

      final night = _extractMealFromResponse(results[1]);

      setState(() {
        if (morning != null) {
          morningMeal = morning;
          morningMealId = _extractMealId(morning) ?? '';
        } else {
          morningMeal = {};
          morningMealId = '';
        }

        if (night != null) {
          nightMeal = night;
          nightMealId = _extractMealId(night) ?? '';
        } else {
          nightMeal = {};
          nightMealId = '';
        }

        isLoadingMeals = false;
      });

      if (morningMealId.isNotEmpty || nightMealId.isNotEmpty) {
        await _fetchCurrentStatus();
      }
    } catch (e) {
      debugPrint('Meal loading error: $e');

      if (!mounted) return;

      setState(() {
        isLoadingMeals = false;

        morningMeal = {};
        nightMeal = {};

        morningMealId = '';
        nightMealId = '';
      });

      _showSnackBar('Unable to load meals for $dateString', danger);
    }
  }

  Map<String, dynamic>? _extractMealFromResponse(dynamic response) {
    if (response is! Map) {
      return null;
    }

    final Map<String, dynamic> result = Map<String, dynamic>.from(response);

    if (result['success'] != true) {
      return null;
    }

    final dynamic data = result['data'];

    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first);
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    final dynamic meal = result['meal'];

    if (meal is Map) {
      return Map<String, dynamic>.from(meal);
    }

    return null;
  }

  // ===========================================================================
  // MEAL HELPERS
  // ===========================================================================

  String? _extractMealId(Map<String, dynamic> meal) {
    final dynamic id = meal['_id'] ?? meal['id'] ?? meal['mealId'];

    if (id == null) {
      return null;
    }

    return id.toString();
  }

  String _baseMenu(Map<String, dynamic> meal) {
    return (meal['manu'] ?? meal['menu'] ?? 'veg').toString().toLowerCase();
  }

  String _mealNumber(Map<String, dynamic> meal) {
    return (meal['mealsNum'] ??
            meal['mealNum'] ??
            meal['serialNumber'] ??
            'N/A')
        .toString();
  }

  String _convertSavedChoice(String savedChoice, Map<String, dynamic> meal) {
    final String choice = savedChoice.toLowerCase();

    if (choice == 'halal_chicken') {
      return 'halal_chicken';
    }

    if (choice == 'egg' || choice == 'egg_substitute') {
      return 'egg_substitute';
    }

    if (choice == 'veg' && _baseMenu(meal) != 'veg') {
      return 'veg_forced';
    }

    return 'regular';
  }

  IconData _getMealIcon(String mealType) {
    final type = mealType.toLowerCase();

    if (type.contains('chicken')) {
      return Icons.kebab_dining_rounded;
    }

    if (type.contains('egg')) {
      return Icons.egg_rounded;
    }

    if (type.contains('fish')) {
      return Icons.set_meal_rounded;
    }

    if (type.contains('mutton')) {
      return Icons.dinner_dining_rounded;
    }

    if (type.contains('paneer')) {
      return Icons.bakery_dining_rounded;
    }

    return Icons.grass_rounded;
  }

  Color _getMealColor(String mealType) {
    final type = mealType.toLowerCase();

    if (type.contains('chicken') || type.contains('mutton')) {
      return danger;
    }

    if (type.contains('egg')) {
      return warning;
    }

    if (type.contains('fish')) {
      return info;
    }

    if (type.contains('paneer')) {
      return const Color(0xFF9333EA);
    }

    return success;
  }

  String _getPreferenceLabel(String preference, String baseMenu) {
    final code = preference.toLowerCase();

    if (code == 'halal_chicken') {
      return 'HALAL CHICKEN';
    }

    if (code == 'egg' || code == 'egg_substitute') {
      return 'EGG SUBSTITUTE';
    }

    if (code == 'veg' || code == 'veg_forced') {
      return 'VEGETARIAN';
    }

    return 'REGULAR • ${baseMenu.toUpperCase()}';
  }

  // ===========================================================================
  // MEAL STATE
  // ===========================================================================

  ({
    bool exists,
    bool cancelled,
    bool locked,
    bool voted,
    DateTime lockDateTime,
    String deadline,
    String remaining,
  })
  _getMealState(Map<String, dynamic> meal, String slot) {
    if (meal.isEmpty) {
      final now = DateTime.now();

      return (
        exists: false,
        cancelled: false,
        locked: true,
        voted: false,
        lockDateTime: now,
        deadline: 'N/A',
        remaining: 'N/A',
      );
    }

    final bool cancelled = meal['isCancelled'] == true;

    final String lockTime = meal['lockTime']?.toString() ?? '';

    final DateTime lockDateTime = _parseLockTime(lockTime);

    final bool timeExpired = DateTime.now().isAfter(lockDateTime);

    final bool locked = meal['isLocked'] == true || timeExpired;

    final bool voted = userVotes[slot] == true;

    return (
      exists: true,
      cancelled: cancelled,
      locked: locked,
      voted: voted,
      lockDateTime: lockDateTime,
      deadline: DateFormat('hh:mm a, dd MMM').format(lockDateTime),
      remaining: _getTimeRemaining(lockDateTime),
    );
  }

  DateTime _parseLockTime(String lockTimeIso) {
    try {
      final DateTime lock = DateTime.parse(lockTimeIso);

      return DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        lock.hour,
        lock.minute,
      );
    } catch (_) {
      return DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        12,
        0,
      );
    }
  }

  String _getTimeRemaining(DateTime lockTime) {
    final Duration difference = lockTime.difference(DateTime.now());

    if (difference.isNegative) {
      return 'Closed';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays}d '
          '${difference.inHours % 24}h';
    }

    if (difference.inHours > 0) {
      return '${difference.inHours}h '
          '${difference.inMinutes % 60}m';
    }

    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    }

    return 'Few seconds';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    final morningState = _getMealState(morningMeal, 'morning');

    final nightState = _getMealState(nightMeal, 'night');

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          color: primary,
          onRefresh: () => _loadMealsForDate(selectedDate),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              SliverToBoxAdapter(child: _buildVotingAccessBanner()),

              if (isLoadingMeals)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildDateSelector()),

                SliverToBoxAdapter(
                  child: _buildSummary(morningState, nightState),
                ),

                SliverToBoxAdapter(
                  child: _buildMealCard(
                    title: 'Morning',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: warning,
                    meal: morningMeal,
                    state: morningState,
                    slot: 'morning',
                  ),
                ),

                SliverToBoxAdapter(
                  child: _buildMealCard(
                    title: 'Night',
                    icon: Icons.nightlight_round,
                    iconColor: primary,
                    meal: nightMeal,
                    state: nightState,
                    slot: 'night',
                  ),
                ),

                SliverToBoxAdapter(
                  child: _buildVoteAllButton(morningState, nightState),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [primary, primaryDark]),
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: const Icon(
              Icons.how_to_vote_rounded,
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
                  'Meal Voting',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Choose your meals and preferences',
                  style: TextStyle(color: textGrey, fontSize: 10.5),
                ),
              ],
            ),
          ),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _loadMealsForDate(selectedDate),
              child: Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: textGrey,
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
  // ACCESS BANNER
  // ===========================================================================

  Widget _buildVotingAccessBanner() {
    if (isCheckingVotingAccess) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            ),
            SizedBox(width: 9),
            Text(
              'Checking voting access...',
              style: TextStyle(
                color: textGrey,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (canUserVote) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isPrivilegedUser()
                    ? 'Manager/Admin voting access enabled.'
                    : 'Active meal pack detected. You can vote.',
                style: const TextStyle(
                  color: Color(0xFF166534),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: warning, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voting is restricted',
                  style: TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'An active meal pack is required to vote.',
                  style: TextStyle(color: Color(0xFF9A3412), fontSize: 8.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DATE SELECTOR
  // ===========================================================================

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: _selectMealDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE8E9EF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: primary,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEAL DATE',
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prettyDate,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CHANGE',
                        style: TextStyle(
                          color: primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: primary,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectMealDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    if (picked.year == selectedDate.year &&
        picked.month == selectedDate.month &&
        picked.day == selectedDate.day) {
      return;
    }

    setState(() {
      selectedDate = picked;
    });

    await _loadMealsForDate(picked);
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary(dynamic morningState, dynamic nightState) {
    final int completed = [
      morningState.voted,
      nightState.voted,
    ].where((value) => value == true).length;

    final int available = [
      morningState.exists &&
          !morningState.cancelled &&
          !morningState.locked &&
          !morningState.voted,
      nightState.exists &&
          !nightState.cancelled &&
          !nightState.locked &&
          !nightState.voted,
    ].where((value) => value == true).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAEAF0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _summaryItem(
                icon: Icons.check_circle_rounded,
                color: success,
                value: '$completed/2',
                label: 'VOTED',
              ),
            ),

            Container(width: 1, height: 35, color: const Color(0xFFE5E7EB)),

            Expanded(
              child: _summaryItem(
                icon: Icons.how_to_vote_rounded,
                color: primary,
                value: '$available',
                label: 'AVAILABLE',
              ),
            ),

            Container(width: 1, height: 35, color: const Color(0xFFE5E7EB)),

            Expanded(
              child: _summaryItem(
                icon: Icons.calendar_today_rounded,
                color: info,
                value: DateFormat('dd').format(selectedDate),
                label: DateFormat('MMM').format(selectedDate).toUpperCase(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: textDark,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: textGrey,
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MEAL CARD
  // ===========================================================================

  Widget _buildMealCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Map<String, dynamic> meal,
    required dynamic state,
    required String slot,
  }) {
    if (!state.exists) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _buildUnavailableMeal(title, icon, iconColor),
      );
    }

    final String baseMenu = _baseMenu(meal);

    final bool canVote =
        canUserVote && !state.cancelled && !state.locked && !state.voted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: state.voted
                ? success.withOpacity(0.35)
                : state.cancelled
                ? danger.withOpacity(0.25)
                : state.locked
                ? const Color(0xFFE5E7EB)
                : primary.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Meal #${_mealNumber(meal)}',
                          style: const TextStyle(
                            color: textGrey,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildStatusBadge(state),
                ],
              ),

              const SizedBox(height: 17),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getMealIcon(baseMenu),
                      color: _getMealColor(baseMenu),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BASE MENU',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      baseMenu.toUpperCase(),
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: textGrey, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Voting deadline',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    state.deadline,
                    style: TextStyle(
                      color: state.locked ? danger : textDark,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              if (!state.locked && !state.cancelled && !state.voted) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Ends in ${state.remaining}',
                    style: const TextStyle(
                      color: warning,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],

              // -----------------------------------------------------------------
              // VOTED
              // -----------------------------------------------------------------
              if (state.voted) ...[
                const SizedBox(height: 15),

                _buildSavedVote(slot, baseMenu),

                const SizedBox(height: 12),

                _buildCancelVoteButton(
                  slot: slot,
                  mealId: slot == 'morning' ? morningMealId : nightMealId,
                ),
              ],

              // -----------------------------------------------------------------
              // VOTING OPTIONS
              // -----------------------------------------------------------------
              if (canVote) ...[
                const SizedBox(height: 18),

                const Text(
                  'SELECT YOUR PREFERENCE',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 9),

                _buildPreferenceOptions(slot, baseMenu),

                const SizedBox(height: 10),

                _buildSubmitButton(
                  slot: slot,
                  mealId: slot == 'morning' ? morningMealId : nightMealId,
                  meal: meal,
                ),
              ],

              // -----------------------------------------------------------------
              // PACK REQUIRED
              // -----------------------------------------------------------------
              if (!canUserVote &&
                  !state.cancelled &&
                  !state.locked &&
                  !state.voted &&
                  !isCheckingVotingAccess)
                _buildClosedMessage(
                  Icons.lock_outline_rounded,
                  'MEAL PACK REQUIRED',
                  warning,
                ),

              // -----------------------------------------------------------------
              // CANCELLED / CLOSED
              // -----------------------------------------------------------------
              if (state.cancelled)
                _buildClosedMessage(
                  Icons.cancel_rounded,
                  'MEAL CANCELLED',
                  danger,
                )
              else if (state.locked && !state.voted)
                _buildClosedMessage(
                  Icons.lock_clock_rounded,
                  'VOTING CLOSED',
                  warning,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUBMIT BUTTON
  // ===========================================================================

  Widget _buildSubmitButton({
    required String slot,
    required String mealId,
    required Map<String, dynamic> meal,
  }) {
    final bool processing = isActionLoading && processingSlot == slot;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isActionLoading || mealId.isEmpty
            ? null
            : () {
                _submitVote(slot: slot, mealId: mealId, meal: meal);
              },
        child: processing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  ),
                  SizedBox(width: 9),
                  Text(
                    'SUBMITTING...',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_vote_rounded, size: 18),
                  SizedBox(width: 7),
                  Text(
                    'SUBMIT VOTE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // SUBMIT VOTE
  // ===========================================================================

  Future<void> _submitVote({
    required String slot,
    required String mealId,
    required Map<String, dynamic> meal,
  }) async {
    if (isCheckingVotingAccess) {
      _showSnackBar('Checking voting access...', warning);
      return;
    }

    final bool access = await _canVoteNow();

    if (!access) {
      if (mounted) {
        setState(() {
          canUserVote = false;
        });

        _showMealPackRequiredDialog();
      }
      return;
    }

    if (mealId.isEmpty) {
      _showSnackBar('Meal ID is missing.', danger);
      return;
    }

    if (meal['isCancelled'] == true) {
      _showSnackBar('This meal has been cancelled.', danger);
      return;
    }

    final state = _getMealState(meal, slot);

    if (state.locked) {
      _showSnackBar('Voting for this meal is closed.', warning);
      return;
    }

    if (userVotes[slot] == true) {
      _showSnackBar('You have already voted for this meal.', success);
      return;
    }

    final String preference = selectedPreferences[slot] ?? 'regular';

    final String baseMenu = _baseMenu(meal);

    final bool? confirmed = await _showSingleVoteConfirmation(
      slot,
      preference,
      baseMenu,
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    // Final access check after confirmation.
    final bool finalAccess = await _canVoteNow();

    if (!finalAccess) {
      if (mounted) {
        setState(() {
          canUserVote = false;
        });

        _showMealPackRequiredDialog();
      }
      return;
    }

    setState(() {
      isActionLoading = true;
      processingSlot = slot;
      userVotes[slot] = true;
    });

    try {
      final response = await api.postVote({
        'mealId': mealId,
        'timeSlot': slot,
        'mealType': preference,
      });

      if (!mounted) return;

      if (response['success'] == true) {
        activeSavedChoices[slot] = preference;

        _showSnackBar(
          '${slot == 'morning' ? 'Morning' : 'Night'} '
          'vote recorded successfully!',
          success,
        );

        await _fetchCurrentStatus();
      } else {
        throw Exception(response['message'] ?? 'Vote failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userVotes[slot] = false;
        });

        _showSnackBar('❌ ${e.toString()}', danger);
      }
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
          processingSlot = null;
        });
      }
    }
  }

  // ===========================================================================
  // CANCEL VOTE BUTTON
  // ===========================================================================

  Widget _buildCancelVoteButton({
    required String slot,
    required String mealId,
  }) {
    final bool processing = isActionLoading && processingSlot == slot;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: danger,
          side: BorderSide(color: danger.withOpacity(0.35)),
          backgroundColor: danger.withOpacity(0.045),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isActionLoading || mealId.isEmpty
            ? null
            : () {
                _handleCancelVote(slot: slot, mealId: mealId);
              },
        child: processing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: danger,
                      strokeWidth: 2.2,
                    ),
                  ),
                  SizedBox(width: 9),
                  Text(
                    'CANCELLING...',
                    style: TextStyle(
                      color: danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_circle_outline_rounded, size: 19),
                  SizedBox(width: 7),
                  Text(
                    'CANCEL VOTE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // CANCEL VOTE
  // ===========================================================================

  Future<void> _handleCancelVote({
    required String slot,
    required String mealId,
  }) async {
    if (isCheckingVotingAccess) {
      _showSnackBar('Checking voting access...', warning);
      return;
    }

    final bool access = await _canVoteNow();

    if (!access) {
      if (!mounted) return;

      setState(() {
        canUserVote = false;
      });

      _showMealPackRequiredDialog();
      return;
    }

    if (mealId.isEmpty) {
      _showSnackBar('Meal ID is missing.', danger);
      return;
    }

    final bool? confirmed = await _showCancelConfirmation(slot);

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    final bool originalVoteState = userVotes[slot] ?? false;

    final String originalChoice = activeSavedChoices[slot] ?? '';

    final String originalPreference = selectedPreferences[slot] ?? 'regular';

    setState(() {
      isActionLoading = true;
      processingSlot = slot;

      userVotes[slot] = false;
      activeSavedChoices[slot] = '';
      selectedPreferences[slot] = 'regular';
    });

    try {
      final response = await api.cancelVote(mealId, slot.toLowerCase());

      if (!mounted) return;

      if (response['success'] == true) {
        _showSnackBar(
          '${slot == 'morning' ? 'Morning' : 'Night'} '
          'vote cancelled successfully!',
          warning,
        );

        await _fetchCurrentStatus();
      } else {
        throw Exception(response['message'] ?? 'Cancel vote failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userVotes[slot] = originalVoteState;

          activeSavedChoices[slot] = originalChoice;

          selectedPreferences[slot] = originalPreference;
        });

        _showSnackBar('❌ ${e.toString()}', danger);
      }
    } finally {
      if (mounted) {
        setState(() {
          isActionLoading = false;
          processingSlot = null;
        });
      }
    }
  }

  // ===========================================================================
  // CONFIRM VOTE
  // ===========================================================================

  Future<bool?> _showSingleVoteConfirmation(
    String slot,
    String preference,
    String baseMenu,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.how_to_vote_rounded, color: primary),
              SizedBox(width: 9),
              Text(
                'Confirm Vote',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _confirmationRow('Meal', slot == 'morning' ? 'Morning' : 'Night'),
              const SizedBox(height: 8),
              _confirmationRow(
                'Preference',
                _getPreferenceLabel(preference, baseMenu),
              ),
              const SizedBox(height: 15),
              const Text(
                'Do you want to submit this vote?',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(color: textGrey, fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'CONFIRM',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _confirmationRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: textGrey, fontSize: 10)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textDark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CANCEL CONFIRMATION
  // ===========================================================================

  Future<bool?> _showCancelConfirmation(String slot) {
    final String title = slot == 'morning' ? 'Morning' : 'Night';

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.remove_circle_outline_rounded, color: danger),
              SizedBox(width: 9),
              Text(
                'Cancel Vote?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: danger,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '$title • '
                        '${DateFormat('dd MMM yyyy').format(selectedDate)}',
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your vote will be removed and you will be able to vote again while voting is still open.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 10, height: 1.45),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'KEEP VOTE',
                style: TextStyle(
                  color: textGrey,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'CANCEL VOTE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // SAVED VOTE
  // ===========================================================================

  Widget _buildSavedVote(String slot, String baseMenu) {
    final String saved = activeSavedChoices[slot] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: success, size: 19),
          const SizedBox(width: 8),
          const Text(
            'YOUR SELECTION',
            style: TextStyle(
              color: success,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              _getPreferenceLabel(saved, baseMenu),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF166534),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PREFERENCE OPTIONS
  // ===========================================================================

  Widget _buildPreferenceOptions(String slot, String baseMenu) {
    final List<Widget> options = [];

    options.add(
      _preferenceTile(
        slot: slot,
        value: 'regular',
        title: 'Regular Option',
        subtitle: baseMenu.toUpperCase(),
        icon: _getMealIcon(baseMenu),
        color: _getMealColor(baseMenu),
      ),
    );

    if (baseMenu == 'egg') {
      options.add(
        _preferenceTile(
          slot: slot,
          value: 'veg_forced',
          title: 'Vegetarian Alternative',
          subtitle: 'PURE VEG',
          icon: Icons.grass_rounded,
          color: success,
        ),
      );
    } else if (baseMenu == 'chicken') {
      options.add(
        _preferenceTile(
          slot: slot,
          value: 'halal_chicken',
          title: 'Halal Chicken',
          subtitle: 'HALAL OPTION',
          icon: Icons.workspace_premium_rounded,
          color: danger,
        ),
      );

      options.add(
        _preferenceTile(
          slot: slot,
          value: 'egg_substitute',
          title: 'Egg Substitute',
          subtitle: 'EGG OPTION',
          icon: Icons.egg_rounded,
          color: warning,
        ),
      );

      options.add(
        _preferenceTile(
          slot: slot,
          value: 'veg_forced',
          title: 'Vegetarian Alternative',
          subtitle: 'PURE VEG',
          icon: Icons.grass_rounded,
          color: success,
        ),
      );
    } else if (baseMenu == 'fish' ||
        baseMenu == 'mutton' ||
        baseMenu == 'paneer') {
      options.add(
        _preferenceTile(
          slot: slot,
          value: 'egg_substitute',
          title: 'Egg Substitute',
          subtitle: 'EGG OPTION',
          icon: Icons.egg_rounded,
          color: warning,
        ),
      );

      options.add(
        _preferenceTile(
          slot: slot,
          value: 'veg_forced',
          title: 'Vegetarian Alternative',
          subtitle: 'PURE VEG',
          icon: Icons.grass_rounded,
          color: success,
        ),
      );
    }

    return Column(children: options);
  }

  Widget _preferenceTile({
    required String slot,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final bool selected = selectedPreferences[slot] == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withOpacity(0.07) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isActionLoading
              ? null
              : () {
                  setState(() {
                    selectedPreferences[slot] = value;
                  });
                },
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : const Color(0xFFE5E7EB),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? color : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // VOTE ALL
  // ===========================================================================

  Widget _buildVoteAllButton(dynamic morningState, dynamic nightState) {
    final bool morningReady =
        morningState.exists &&
        !morningState.cancelled &&
        !morningState.locked &&
        !morningState.voted;

    final bool nightReady =
        nightState.exists &&
        !nightState.cancelled &&
        !nightState.locked &&
        !nightState.voted;

    final int readyCount = [
      morningReady,
      nightReady,
    ].where((value) => value).length;

    final int votedCount = [
      morningState.voted,
      nightState.voted,
    ].where((value) => value).length;

    if (readyCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: votedCount == 2
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                votedCount == 2
                    ? Icons.task_alt_rounded
                    : Icons.info_outline_rounded,
                color: votedCount == 2 ? success : textGrey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                votedCount == 2
                    ? 'ALL MEALS VOTED'
                    : 'NO MEALS AVAILABLE TO VOTE',
                style: TextStyle(
                  color: votedCount == 2 ? success : textGrey,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!canUserVote && !isCheckingVotingAccess) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: GestureDetector(
          onTap: _showMealPackRequiredDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: warning, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voting unavailable',
                        style: TextStyle(
                          color: Color(0xFF9A3412),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Activate a meal pack to vote for your meals.',
                        style: TextStyle(color: Color(0xFF9A3412), fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: warning, size: 14),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, primaryDark],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.20),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Vote',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Submit all remaining meals together',
                        style: TextStyle(color: Colors.white70, fontSize: 9.5),
                      ),
                    ],
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
                    '$readyCount MEAL'
                    '${readyCount == 1 ? '' : 'S'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 53,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: isActionLoading
                    ? null
                    : () => _voteAllSelected(morningState, nightState),
                child: isActionLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: primary,
                            ),
                          ),
                          SizedBox(width: 9),
                          Text(
                            'SUBMITTING...',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.done_all_rounded, size: 19),
                          const SizedBox(width: 8),
                          Text(
                            votedCount > 0 ? 'VOTE REMAINING' : 'VOTE ALL',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _voteAllSelected(
    dynamic morningState,
    dynamic nightState,
  ) async {
    if (isCheckingVotingAccess) {
      _showSnackBar('Checking voting access...', warning);
      return;
    }

    final bool access = await _canVoteNow();

    if (!access) {
      if (!mounted) return;

      setState(() {
        canUserVote = false;
      });

      _showMealPackRequiredDialog();
      return;
    }

    final List<Map<String, String>> votes = [];

    if (morningState.exists &&
        !morningState.cancelled &&
        !morningState.locked &&
        !morningState.voted &&
        morningMealId.isNotEmpty) {
      votes.add({
        'slot': 'morning',
        'mealId': morningMealId,
        'mealType': selectedPreferences['morning'] ?? 'regular',
      });
    }

    if (nightState.exists &&
        !nightState.cancelled &&
        !nightState.locked &&
        !nightState.voted &&
        nightMealId.isNotEmpty) {
      votes.add({
        'slot': 'night',
        'mealId': nightMealId,
        'mealType': selectedPreferences['night'] ?? 'regular',
      });
    }

    if (votes.isEmpty) {
      _showSnackBar('There are no meals ready for voting.', warning);
      return;
    }

    final bool? confirmed = await _showVoteAllConfirmation(votes);

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    final bool finalAccess = await _canVoteNow();

    if (!finalAccess) {
      if (!mounted) return;

      setState(() {
        canUserVote = false;
      });

      _showMealPackRequiredDialog();
      return;
    }

    setState(() {
      isActionLoading = true;
      processingSlot = 'all';
    });

    int successCount = 0;
    int failedCount = 0;

    for (final vote in votes) {
      try {
        final response = await api.postVote({
          'mealId': vote['mealId'],
          'timeSlot': vote['slot'],
          'mealType': vote['mealType'],
        });

        if (response['success'] == true) {
          successCount++;

          if (mounted) {
            setState(() {
              userVotes[vote['slot']!] = true;
            });
          }
        } else {
          failedCount++;
        }
      } catch (e) {
        failedCount++;

        debugPrint('Vote error ${vote['slot']}: $e');
      }
    }

    if (!mounted) return;

    await _fetchCurrentStatus();

    if (!mounted) return;

    setState(() {
      isActionLoading = false;
      processingSlot = null;
    });

    if (successCount > 0 && failedCount == 0) {
      _showSnackBar(
        successCount == 2
            ? 'Morning and Night votes submitted!'
            : 'Vote submitted successfully!',
        success,
      );
    } else if (successCount > 0) {
      _showSnackBar(
        '$successCount vote submitted, '
        '$failedCount failed.',
        warning,
      );
    } else {
      _showSnackBar('Unable to submit votes.', danger);
    }
  }

  // ===========================================================================
  // VOTE ALL CONFIRMATION
  // ===========================================================================

  Future<bool?> _showVoteAllConfirmation(List<Map<String, String>> votes) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.done_all_rounded, color: primary),
              SizedBox(width: 9),
              Text('Vote All?', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...votes.map((vote) {
                final String slot = vote['slot']!;

                final Map<String, dynamic> meal = slot == 'morning'
                    ? morningMeal
                    : nightMeal;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        slot == 'morning'
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        color: slot == 'morning' ? warning : primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slot == 'morning' ? 'Morning' : 'Night',
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _getPreferenceLabel(
                            vote['mealType'] ?? 'regular',
                            _baseMenu(meal),
                          ),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: primary,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 5),
              const Text(
                'The selected votes will be submitted together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(color: textGrey, fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'CONFIRM',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // MEAL PACK REQUIRED
  // ===========================================================================

  void _showMealPackRequiredDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: primary),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Voting Restricted',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'You need an active meal pack to vote for meals.',
            style: TextStyle(color: textGrey, fontSize: 11, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'OK',
                style: TextStyle(color: primary, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // UNAVAILABLE MEAL
  // ===========================================================================

  Widget _buildUnavailableMeal(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF9CA3AF), size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title Meal',
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'No meal available for this date.',
                  style: TextStyle(color: textGrey, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATUS BADGE
  // ===========================================================================

  Widget _buildStatusBadge(dynamic state) {
    Color color;
    String label;
    IconData icon;

    if (state.cancelled) {
      color = danger;
      label = 'CANCELLED';
      icon = Icons.cancel_rounded;
    } else if (state.voted) {
      color = success;
      label = 'VOTED';
      icon = Icons.check_circle_rounded;
    } else if (state.locked) {
      color = warning;
      label = 'CLOSED';
      icon = Icons.lock_rounded;
    } else if (!canUserVote && !isCheckingVotingAccess) {
      color = warning;
      label = 'PACK REQUIRED';
      icon = Icons.lock_outline_rounded;
    } else {
      color = info;
      label = 'OPEN';
      icon = Icons.how_to_vote_rounded;
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
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CLOSED MESSAGE
  // ===========================================================================

  Widget _buildClosedMessage(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }
}
