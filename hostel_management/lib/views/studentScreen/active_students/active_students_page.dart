import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:HostelMess/services/api_service.dart';

class ActiveStudentsPage extends StatefulWidget {
  const ActiveStudentsPage({super.key});

  @override
  State<ActiveStudentsPage> createState() => _ActiveStudentsPageState();
}

class _ActiveStudentsPageState extends State<ActiveStudentsPage> {
  final ApiService api = ApiService();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFilter = 'All';

  DateTime? _cycleStart;
  DateTime? _cycleEnd;

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================

  static const Color green = Color(0xFF16A05D);
  static const Color red = Color(0xFFDC2626);
  static const Color orange = Color(0xFFD97706);

  // ============================================================
  // THEME HELPERS
  // ============================================================

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _primaryDark => const Color(0xFF3F35A8);

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _divider => Theme.of(context).dividerColor;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _borderColor =>
      _isDark ? const Color(0xFF2C303A) : const Color(0xFFEAEAF0);

  Color get _subtleSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF3F4F6);

  Color get _purpleSoft =>
      _isDark ? const Color(0xFF292650) : const Color(0xFFEEEDFF);

  Color get _greenSoft =>
      _isDark ? const Color(0xFF173527) : const Color(0xFFECFDF5);

  Color get _redSoft =>
      _isDark ? const Color(0xFF351C23) : const Color(0xFFFFF1F2);

  Color get _avatarGreen =>
      _isDark ? const Color(0xFF193A2A) : const Color(0xFFEAFBF2);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilters);

    _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD EVERYTHING
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // ----------------------------------------------------------
      // Load current meal cycle
      // ----------------------------------------------------------

      DateTime? cycleStart;
      DateTime? cycleEnd;

      try {
        final bounds = await api.getMealCycleDateBounds();

        cycleStart = _parseDate(
          bounds['startDate'] ??
              bounds['cycleStart'] ??
              bounds['start'] ??
              bounds['from'],
        );

        cycleEnd = _parseDate(
          bounds['endDate'] ??
              bounds['cycleEnd'] ??
              bounds['end'] ??
              bounds['to'],
        );
      } catch (e) {
        debugPrint("Meal cycle bounds error: $e");
      }

      // ----------------------------------------------------------
      // Load active students
      // ----------------------------------------------------------

      final studentsResult = await api.getAllStudentsMnager();

      if (studentsResult == null) {
        throw Exception("Unable to load students.");
      }

      final students = List<dynamic>.from(studentsResult);

      final activeStudents = students
          .where(_isStudentActive)
          .whereType<Map>()
          .map((student) => Map<String, dynamic>.from(student))
          .toList();

      // ----------------------------------------------------------
      // Load subscriptions
      // ----------------------------------------------------------

      List<dynamic> subscriptions = [];

      try {
        final subscriptionResult = await api.getManagerSubscriptions();

        subscriptions = _extractList(subscriptionResult);
      } catch (e) {
        debugPrint("Subscription API error: $e");
      }

      debugPrint("========== MEAL PACK STATUS ==========");
      debugPrint("Students: ${activeStudents.length}");
      debugPrint("Subscriptions: ${subscriptions.length}");
      debugPrint("Cycle Start: $cycleStart");
      debugPrint("Cycle End: $cycleEnd");
      debugPrint("======================================");

      // ----------------------------------------------------------
      // Determine current-cycle meal pack status
      // ----------------------------------------------------------

      final processedStudents = <Map<String, dynamic>>[];

      for (final student in activeStudents) {
        final subscription = _findCurrentSubscription(
          student,
          subscriptions,
          cycleStart,
          cycleEnd,
        );

        final hasMealPack = subscription != null;

        final item = Map<String, dynamic>.from(student);

        item['_hasMealPack'] = hasMealPack;

        if (subscription != null) {
          item['_subscription'] = subscription;
        }

        processedStudents.add(item);

        debugPrint(
          "MEAL PACK: ${_getName(student)} => "
          "${hasMealPack ? 'TAKEN' : 'NOT TAKEN'}",
        );
      }

      if (!mounted) return;

      setState(() {
        _cycleStart = cycleStart;
        _cycleEnd = cycleEnd;

        _allStudents = processedStudents;

        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint("Meal Pack Status Error: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load meal pack status.";
      });
    }
  }

  // ============================================================
  // EXTRACT LIST
  // ============================================================

  List<dynamic> _extractList(dynamic result) {
    if (result == null) {
      return [];
    }

    if (result is List) {
      return result;
    }

    if (result is Map) {
      final possibleKeys = [
        'data',
        'subscriptions',
        'results',
        'mealSubscriptions',
        'items',
      ];

      for (final key in possibleKeys) {
        final value = result[key];

        if (value is List) {
          return value;
        }

        if (value is Map) {
          final nested = _extractList(value);

          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }
    }

    return [];
  }

  // ============================================================
  // FIND CURRENT SUBSCRIPTION
  // ============================================================

  Map<String, dynamic>? _findCurrentSubscription(
    Map student,
    List<dynamic> subscriptions,
    DateTime? cycleStart,
    DateTime? cycleEnd,
  ) {
    final studentIds = _getPossibleStudentIds(student);

    final matchingSubscriptions = <Map<String, dynamic>>[];

    for (final raw in subscriptions) {
      if (raw is! Map) continue;

      final subscription = Map<String, dynamic>.from(raw);

      if (!_subscriptionBelongsToStudent(subscription, studentIds)) {
        continue;
      }

      if (_isSubscriptionCompleted(subscription)) {
        continue;
      }

      matchingSubscriptions.add(subscription);
    }

    for (final subscription in matchingSubscriptions) {
      if (_isSubscriptionForCurrentCycle(subscription, cycleStart, cycleEnd)) {
        return subscription;
      }
    }

    if (cycleStart == null && cycleEnd == null) {
      if (matchingSubscriptions.isNotEmpty) {
        return matchingSubscriptions.first;
      }
    }

    return null;
  }

  // ============================================================
  // STUDENT IDS
  // ============================================================

  List<String> _getPossibleStudentIds(Map student) {
    final ids = <String>{};

    final values = [
      student['_id'],
      student['id'],
      student['studentId'],
      student['studentID'],
      student['userId'],
      student['userID'],
      student['registrationNo'],
      student['registrationNumber'],
      student['rollNo'],
      student['rollNumber'],
      student['email'],
    ];

    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        ids.add(value.toString().trim());
      }
    }

    final nestedObjects = [
      student['user'],
      student['student'],
      student['profile'],
      student['studentDetails'],
    ];

    for (final nested in nestedObjects) {
      if (nested is Map) {
        final nestedValues = [
          nested['_id'],
          nested['id'],
          nested['studentId'],
          nested['studentID'],
          nested['userId'],
          nested['userID'],
          nested['email'],
          nested['rollNo'],
          nested['rollNumber'],
        ];

        for (final value in nestedValues) {
          if (value != null && value.toString().trim().isNotEmpty) {
            ids.add(value.toString().trim());
          }
        }
      }
    }

    return ids.toList();
  }

  // ============================================================
  // CHECK SUBSCRIPTION OWNER
  // ============================================================

  bool _subscriptionBelongsToStudent(
    Map subscription,
    List<String> studentIds,
  ) {
    if (studentIds.isEmpty) {
      return false;
    }

    final valuesToCheck = <dynamic>[
      subscription['studentId'],
      subscription['studentID'],
      subscription['userId'],
      subscription['userID'],
      subscription['memberId'],
      subscription['memberID'],
      subscription['customerId'],
      subscription['customerID'],
      subscription['email'],
    ];

    final nestedObjects = [
      subscription['student'],
      subscription['user'],
      subscription['member'],
      subscription['customer'],
      subscription['userDetails'],
      subscription['studentDetails'],
    ];

    for (final value in valuesToCheck) {
      if (value != null) {
        if (_valueMatchesStudent(value, studentIds)) {
          return true;
        }
      }
    }

    for (final nested in nestedObjects) {
      if (nested is Map) {
        if (_valueMatchesStudentMap(nested, studentIds)) {
          return true;
        }
      } else if (nested != null) {
        if (studentIds.contains(nested.toString().trim())) {
          return true;
        }
      }
    }

    return false;
  }

  bool _valueMatchesStudent(dynamic value, List<String> studentIds) {
    if (value == null) {
      return false;
    }

    if (value is Map) {
      return _valueMatchesStudentMap(value, studentIds);
    }

    return studentIds.contains(value.toString().trim());
  }

  bool _valueMatchesStudentMap(Map value, List<String> studentIds) {
    final possibleValues = [
      value['_id'],
      value['id'],
      value['studentId'],
      value['studentID'],
      value['userId'],
      value['userID'],
      value['email'],
    ];

    for (final item in possibleValues) {
      if (item != null && studentIds.contains(item.toString().trim())) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CURRENT CYCLE CHECK
  // ============================================================

  bool _isSubscriptionForCurrentCycle(
    Map subscription,
    DateTime? cycleStart,
    DateTime? cycleEnd,
  ) {
    if (cycleStart == null && cycleEnd == null) {
      return true;
    }

    final start = _parseDate(
      subscription['startDate'] ??
          subscription['cycleStart'] ??
          subscription['start'] ??
          subscription['from'] ??
          subscription['subscriptionStartDate'] ??
          subscription['createdAt'],
    );

    final end = _parseDate(
      subscription['endDate'] ??
          subscription['cycleEnd'] ??
          subscription['end'] ??
          subscription['to'] ??
          subscription['subscriptionEndDate'],
    );

    if (start != null && end != null) {
      if (cycleStart != null && cycleEnd != null) {
        return _sameDay(start, cycleStart) && _sameDay(end, cycleEnd);
      }

      if (cycleStart != null) {
        return !start.isBefore(cycleStart);
      }

      if (cycleEnd != null) {
        return !end.isAfter(cycleEnd);
      }
    }

    final current =
        subscription['isCurrent'] ??
        subscription['current'] ??
        subscription['isActive'];

    if (current is bool) {
      return current;
    }

    final status = subscription['status']?.toString().toLowerCase();

    if (status == 'active' ||
        status == 'ongoing' ||
        status == 'current' ||
        status == 'approved') {
      return true;
    }

    if (start == null && end == null) {
      return true;
    }

    return false;
  }

  // ============================================================
  // COMPLETED SUBSCRIPTION
  // ============================================================

  bool _isSubscriptionCompleted(Map subscription) {
    final status = subscription['status']?.toString().toLowerCase().trim();

    return status == 'completed' ||
        status == 'complete' ||
        status == 'expired' ||
        status == 'cancelled' ||
        status == 'canceled';
  }

  // ============================================================
  // ACTIVE STUDENT CHECK
  // ============================================================

  bool _isStudentActive(dynamic student) {
    if (student is! Map) {
      return false;
    }

    final dynamic isActive = student['isActive'];

    if (isActive is bool) {
      return isActive;
    }

    final dynamic active = student['active'];

    if (active is bool) {
      return active;
    }

    final dynamic status = student['status'];

    if (status != null) {
      final value = status.toString().toLowerCase().trim();

      if (value == 'active' || value == 'approved' || value == 'enabled') {
        return true;
      }

      if (value == 'inactive' ||
          value == 'disabled' ||
          value == 'pending' ||
          value == 'rejected') {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _applyFilters() {
    if (!mounted) return;

    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allStudents.where((student) {
      final hasMealPack = student['_hasMealPack'] == true;

      if (_selectedFilter == 'Taken' && !hasMealPack) {
        return false;
      }

      if (_selectedFilter == 'Not Taken' && hasMealPack) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final name = _getName(student).toLowerCase();
      final email = _getEmail(student).toLowerCase();
      final phone = _getPhone(student).toLowerCase();
      final roll = _getRollNumber(student).toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          roll.contains(query);
    }).toList();

    setState(() {
      _filteredStudents = filtered;
    });
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(text);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ============================================================
  // NAME
  // ============================================================

  String _getName(Map student) {
    final value = _findValue(student, [
      'name',
      'fullName',
      'studentName',
      'username',
      'displayName',
    ]);

    return value ?? 'Student';
  }

  // ============================================================
  // EMAIL
  // ============================================================

  String _getEmail(Map student) {
    final value = _findValue(student, ['email', 'emailAddress']);

    return value ?? '';
  }

  // ============================================================
  // PHONE
  // ============================================================

  String _getPhone(Map student) {
    final value = _findValue(student, [
      'phone',
      'phoneNumber',
      'mobile',
      'mobileNumber',
      'contact',
      'contactNumber',
      'contactNo',
      'contact_number',
      'mobileNo',
      'telephone',
      'telephoneNumber',
      'phoneNo',
      'phone_number',
      'mobile_number',
    ]);

    if (value == null) {
      return '';
    }

    return _cleanPhone(value);
  }

  // ============================================================
  // ROLL
  // ============================================================

  String _getRollNumber(Map student) {
    final value = _findValue(student, [
      'rollNo',
      'rollNumber',
      'registrationNo',
      'registrationNumber',
      'studentId',
      'studentID',
      'studentNo',
      'studentNumber',
      'enrollmentNo',
      'enrollmentNumber',
      'regNo',
    ]);

    return value ?? '';
  }

  // ============================================================
  // PHOTO
  // ============================================================

  String _getPhotoUrl(Map student) {
    final value = _findValue(student, [
      'photoURL',
      'photoUrl',
      'photo',
      'profileImage',
      'profileImageUrl',
      'image',
      'imageUrl',
      'avatar',
      'avatarUrl',
    ]);

    return value ?? '';
  }

  // ============================================================
  // FIND VALUE RECURSIVELY
  // ============================================================

  String? _findValue(Map data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = data[key];

      if (_isUsableValue(value)) {
        return value.toString().trim();
      }
    }

    for (final entry in data.entries) {
      final value = entry.value;

      if (value is Map) {
        final result = _findValue(value, possibleKeys);

        if (result != null && result.trim().isNotEmpty) {
          return result;
        }
      }

      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final result = _findValue(item, possibleKeys);

            if (result != null && result.trim().isNotEmpty) {
              return result;
            }
          }
        }
      }
    }

    return null;
  }

  bool _isUsableValue(dynamic value) {
    if (value == null) {
      return false;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return false;
    }

    if (text.toLowerCase() == 'null') {
      return false;
    }

    if (text.toLowerCase() == 'n/a') {
      return false;
    }

    return true;
  }

  // ============================================================
  // PHONE CLEAN
  // ============================================================

  String _cleanPhone(dynamic value) {
    String phone = value.toString().trim();

    phone = phone.replaceAll(RegExp(r'\s+'), '');

    return phone;
  }

  // ============================================================
  // CALL
  // ============================================================

  Future<void> _callStudent(String phone) async {
    final cleanedPhone = phone.trim();

    if (cleanedPhone.isEmpty) {
      _showSnackBar("Phone number not available.");
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: cleanedPhone);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);

      if (!launched) {
        _showSnackBar("Unable to open phone dialer.");
      }
    } catch (e) {
      debugPrint("Call Error: $e");

      _showSnackBar("Unable to make call.");
    }
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _totalStudents {
    return _allStudents.length;
  }

  int get _takenCount {
    return _allStudents
        .where((student) => student['_hasMealPack'] == true)
        .length;
  }

  int get _notTakenCount {
    return _totalStudents - _takenCount;
  }

  double get _takenPercentage {
    if (_totalStudents == 0) {
      return 0;
    }

    return _takenCount / _totalStudents;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,

        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _textPrimary,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Meal Pack Status",
              style: TextStyle(
                color: _textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              "Current cycle meal pack directory",
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadData,
            icon: Icon(Icons.refresh_rounded, color: _textPrimary),
          ),

          const SizedBox(width: 5),
        ],
      ),

      body: RefreshIndicator(
        color: _primary,
        backgroundColor: _surface,
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 40),
      children: [
        _buildCycleCard(),

        const SizedBox(height: 14),

        _buildSummaryCard(),

        const SizedBox(height: 16),

        _buildSearchBar(),

        const SizedBox(height: 14),

        _buildFilterChips(),

        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: Text(
                "STUDENT MEAL PACK STATUS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: _textSecondary,
                ),
              ),
            ),

            Text(
              "${_filteredStudents.length} students",
              style: TextStyle(
                fontSize: 10,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_filteredStudents.isEmpty)
          _buildEmptyState()
        else
          ..._filteredStudents.map((student) => _buildStudentCard(student)),
      ],
    );
  }

  // ============================================================
  // CYCLE CARD
  // ============================================================

  Widget _buildCycleCard() {
    final start = _cycleStart;
    final end = _cycleEnd;

    String cycleText = "Current Meal Cycle";

    if (start != null && end != null) {
      cycleText = "${_formatDate(start)}  –  ${_formatDate(end)}";
    } else if (start != null) {
      cycleText = "From ${_formatDate(start)}";
    } else if (end != null) {
      cycleText = "Until ${_formatDate(end)}";
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryDark],
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CURRENT MEAL CYCLE",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  cycleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: Color(0xFF86EFAC)),

                SizedBox(width: 5),

                Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
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
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.groups_rounded,
                  title: "Total",
                  value: "$_totalStudents",
                  iconColor: _primary,
                  backgroundColor: _purpleSoft,
                ),
              ),

              Container(width: 1, height: 48, color: _divider),

              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.check_circle_rounded,
                  title: "Taken",
                  value: "$_takenCount",
                  iconColor: green,
                  backgroundColor: _greenSoft,
                ),
              ),

              Container(width: 1, height: 48, color: _divider),

              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.remove_circle_rounded,
                  title: "Not Taken",
                  value: "$_notTakenCount",
                  iconColor: red,
                  backgroundColor: _redSoft,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Text(
                "Meal Pack Coverage",
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const Spacer(),

              Text(
                "${(_takenPercentage * 100).round()}%",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _takenPercentage,
              minHeight: 8,
              backgroundColor: _subtleSurface,
              valueColor: AlwaysStoppedAnimation<Color>(green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Column(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),

        const SizedBox(height: 7),

        Text(
          value,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 1),

        Text(
          title,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: _textPrimary, fontSize: 11),
        decoration: InputDecoration(
          hintText: "Search by name, phone or roll number",
          hintStyle: TextStyle(
            color: _textSecondary.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: _primary, size: 21),
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
            vertical: 16,
            horizontal: 4,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTER CHIPS
  // ============================================================

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(label: "All", icon: Icons.groups_rounded),

          const SizedBox(width: 8),

          _buildFilterChip(label: "Taken", icon: Icons.check_circle_rounded),

          const SizedBox(width: 8),

          _buildFilterChip(
            label: "Not Taken",
            icon: Icons.remove_circle_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon}) {
    final selected = _selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });

        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _primary : _borderColor),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),

            if (label == "All") ...[
              const SizedBox(width: 6),
              _filterCount(_totalStudents, selected),
            ],

            if (label == "Taken") ...[
              const SizedBox(width: 6),
              _filterCount(_takenCount, selected),
            ],

            if (label == "Not Taken") ...[
              const SizedBox(width: 6),
              _filterCount(_notTakenCount, selected),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterCount(int count, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.16) : _subtleSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$count",
        style: TextStyle(
          color: selected ? Colors.white : _textSecondary,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = _getName(student);
    final email = _getEmail(student);
    final phone = _getPhone(student);
    final roll = _getRollNumber(student);
    final photoUrl = _getPhotoUrl(student);

    final hasMealPack = student['_hasMealPack'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: hasMealPack
              ? (_isDark ? const Color(0xFF24523A) : const Color(0xFFDDF5E8))
              : _borderColor,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(name, photoUrl, hasMealPack),

          const SizedBox(width: 12),

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
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 7),

                    _buildStatusBadge(hasMealPack),
                  ],
                ),

                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: green),

                    const SizedBox(width: 5),

                    const Text(
                      "Active",
                      style: TextStyle(
                        color: green,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (roll.isNotEmpty) ...[
                      const SizedBox(width: 8),

                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _isDark
                              ? const Color(0xFF5B616C)
                              : const Color(0xFFD1D5DB),
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: Text(
                          roll,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          _buildCallButton(phone),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(bool hasMealPack) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: hasMealPack ? _greenSoft : _redSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasMealPack
                ? Icons.check_circle_rounded
                : Icons.remove_circle_outline_rounded,
            size: 12,
            color: hasMealPack ? green : red,
          ),

          const SizedBox(width: 4),

          Text(
            hasMealPack ? "TAKEN" : "NOT TAKEN",
            style: TextStyle(
              color: hasMealPack ? green : red,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(String name, String photoUrl, bool hasMealPack) {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : "S";

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: hasMealPack ? _avatarGreen : _subtleSurface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitial(initial, hasMealPack);
                },
              )
            : _buildInitial(initial, hasMealPack),
      ),
    );
  }

  Widget _buildInitial(String initial, bool hasMealPack) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: hasMealPack ? green : _textSecondary,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // CALL BUTTON
  // ============================================================

  Widget _buildCallButton(String phone) {
    final hasPhone = phone.trim().isNotEmpty;

    return Material(
      color: hasPhone ? _greenSoft : _subtleSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (hasPhone) {
            _callStudent(phone);
          } else {
            _showSnackBar("Phone number not available.");
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: Icon(
            Icons.phone_rounded,
            color: hasPhone ? green : _textSecondary,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    String title = "No Students Found";
    String subtitle = "Try another search or filter.";

    if (_selectedFilter == "Taken") {
      title = "No Meal Packs Taken";
      subtitle = "No active student has a meal pack in the current cycle.";
    }

    if (_selectedFilter == "Not Taken") {
      title = "Everyone Has a Meal Pack";
      subtitle = "All active students have taken a meal pack for this cycle.";
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _subtleSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _selectedFilter == "Taken"
                  ? Icons.no_meals_rounded
                  : Icons.person_search_rounded,
              color: _textSecondary,
              size: 28,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.32,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: _redSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFFE11D48),
                      size: 29,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    _errorMessage ?? "Something went wrong",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text("Try Again"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return "${date.day.toString().padLeft(2, '0')} "
        "${months[date.month - 1]} "
        "${date.year}";
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }
}
