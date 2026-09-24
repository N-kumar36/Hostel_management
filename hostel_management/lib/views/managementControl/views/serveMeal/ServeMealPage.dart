import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class ServeMealPage extends StatefulWidget {
  const ServeMealPage({super.key});

  @override
  State<ServeMealPage> createState() => _ServeMealPageState();
}

class _ServeMealPageState extends State<ServeMealPage> {
  final ApiService api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedTime = "Morning";

  List<dynamic> _allVotes = [];
  List<dynamic> _filteredVotes = [];

  /// studentId -> subscription information
  final Map<String, Map<String, dynamic>> _subscriptionMap = {};

  bool isLoading = false;
  String? processingId;

  String baseRoutineMenu = "veg";
  String mealSequenceNumber = "0";

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  int get servedCount => _allVotes.where((v) => v['isServed'] == true).length;

  int get notServedCount {
    return _allVotes.where((v) {
      final bool isServed = v['isServed'] == true;
      final String choice = v['choice']?.toString() ?? "";
      final bool hasVoted = choice.isNotEmpty;

      return !isServed && hasVoted;
    }).length;
  }

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _fetchData();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  void _onSearchChanged() {
    final String query = _searchController.text.toLowerCase().trim();

    if (!mounted) return;

    setState(() {
      _filteredVotes = _allVotes.where((vote) {
        final String name = (vote['studentName'] ?? "")
            .toString()
            .toLowerCase();

        return name.contains(query);
      }).toList();
    });
  }

  // ------------------------------------------------------------
  // FETCH DATA
  // ------------------------------------------------------------

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);

    try {
      // ------------------------------------------------------------
      // 1. LOAD MEAL / VOTE DATA
      // ------------------------------------------------------------
      final Map<String, dynamic> mealResponse = await api
          .getDetailedVotesByDate(formattedDate, selectedTime);

      // ------------------------------------------------------------
      // 2. LOAD MEAL PACK INFORMATION SEPARATELY
      //
      // This is only for displaying PACK / NO PACK.
      // It does NOT affect the Serve API.
      // ------------------------------------------------------------
      await _loadMealSubscriptions();

      if (!mounted) return;

      setState(() {
        _allVotes = mealResponse['data'] ?? [];

        mealSequenceNumber = (mealResponse['mealsNum'] ?? "0").toString();

        if (_allVotes.isNotEmpty) {
          final firstItem = _allVotes[0];

          baseRoutineMenu = (firstItem['menuItem'] ?? "veg")
              .toString()
              .toLowerCase();

          if (mealSequenceNumber == "0") {
            mealSequenceNumber = (firstItem['mealsNum'] ?? "0").toString();
          }
        } else {
          baseRoutineMenu = "veg";
        }

        _sortAndFilterList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showSnackBar("Error fetching meal data: $e", Colors.red);
    }
  }

  // ------------------------------------------------------------
  // LOAD MEAL PACK INFORMATION
  // ------------------------------------------------------------

  Future<void> _loadMealSubscriptions() async {
    try {
      final List<dynamic> subscriptions = await api.getManagerSubscriptions();

      _subscriptionMap.clear();

      for (final dynamic item in subscriptions) {
        if (item is! Map) continue;

        final dynamic student = item['studentId'];

        String studentId = "";

        if (student is Map) {
          studentId = (student['_id'] ?? student['id'] ?? "").toString();
        } else {
          studentId = student?.toString() ?? "";
        }

        if (studentId.isEmpty) continue;

        /*
         * Keep the newest subscription for each student.
         *
         * getManagerSubscriptions() already sorts newest first
         * in the backend.
         */
        if (!_subscriptionMap.containsKey(studentId)) {
          _subscriptionMap[studentId] = Map<String, dynamic>.from(item);
        }
      }
    } catch (e) {
      /*
       * Subscription information is only visual information.
       *
       * If this request fails, the Serve functionality must
       * continue working exactly as before.
       */
      debugPrint("Meal subscription status unavailable: $e");
    }
  }

  // ------------------------------------------------------------
  // STUDENT ID
  // ------------------------------------------------------------

  String _getStudentId(Map<String, dynamic> vote) {
    final dynamic rawStudentId = vote['studentId'] ?? vote['userId'];

    if (rawStudentId is Map) {
      return (rawStudentId['_id'] ??
              rawStudentId['id'] ??
              rawStudentId['userId'] ??
              "")
          .toString();
    }

    return rawStudentId?.toString() ?? "";
  }

  // ------------------------------------------------------------
  // MEAL PACK STATUS
  // ------------------------------------------------------------

  Map<String, dynamic> _getMealPackStatus(Map<String, dynamic> vote) {
    final String studentId = _getStudentId(vote);

    if (studentId.isEmpty) {
      return {'status': 'none', 'remaining': 0, 'plan': ''};
    }

    final Map<String, dynamic>? subscription = _subscriptionMap[studentId];

    if (subscription == null) {
      return {'status': 'none', 'remaining': 0, 'plan': ''};
    }

    final String status = (subscription['status'] ?? "")
        .toString()
        .toLowerCase();

    final String plan = (subscription['planType'] ?? "").toString();

    final dynamic maxLimitsRaw = subscription['maxLimits'];

    final dynamic usageRaw = subscription['usage'];

    final Map<String, dynamic> maxLimits = maxLimitsRaw is Map
        ? Map<String, dynamic>.from(maxLimitsRaw)
        : {};

    final Map<String, dynamic> usage = usageRaw is Map
        ? Map<String, dynamic>.from(usageRaw)
        : {};

    int totalRemaining = 0;

    const List<String> mealKeys = [
      'veg',
      'egg',
      'paneer',
      'chicken',
      'fish',
      'mutton',
    ];

    for (final String key in mealKeys) {
      final int max = _toInt(maxLimits[key]);

      final int used = _toInt(usage[key]);

      final int remaining = max - used;

      if (remaining > 0) {
        totalRemaining += remaining;
      }
    }

    /*
     * Only active/pending packages are considered usable.
     */
    final bool usableStatus = status == 'active' || status == 'pending';

    if (!usableStatus) {
      return {'status': 'exhausted', 'remaining': 0, 'plan': plan};
    }

    if (totalRemaining <= 0) {
      return {'status': 'exhausted', 'remaining': 0, 'plan': plan};
    }

    return {'status': 'available', 'remaining': totalRemaining, 'plan': plan};
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is double) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  // ------------------------------------------------------------
  // COMPACT MEAL PACK BADGE
  // ------------------------------------------------------------

  Widget _buildMealPackBadge(Map<String, dynamic> vote) {
    final Map<String, dynamic> pack = _getMealPackStatus(vote);

    final String status = pack['status']?.toString() ?? 'none';

    final int remaining = _toInt(pack['remaining']);

    final String plan = pack['plan']?.toString() ?? "";

    late Color color;
    late String label;
    late IconData icon;

    switch (status) {
      case 'available':
        color = Colors.green;
        icon = Icons.check_circle_rounded;

        label = remaining > 0 ? "PACK • $remaining LEFT" : "PACK AVAILABLE";
        break;

      case 'exhausted':
        color = Colors.orange.shade800;
        icon = Icons.warning_rounded;
        label = "PACK • EMPTY";
        break;

      default:
        color = Colors.red.shade600;
        icon = Icons.remove_circle_rounded;
        label = "NO PACK";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.1,
            ),
          ),

          if (plan.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              "• $plan",
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SORT
  // ------------------------------------------------------------

  void _sortAndFilterList() {
    _allVotes.sort((a, b) {
      int getPriority(Map<String, dynamic> vote) {
        final bool isServed = vote['isServed'] ?? false;

        final String choice = vote['choice']?.toString() ?? "";

        final bool hasVoted = choice.isNotEmpty;

        if (!isServed && hasVoted) {
          return 1;
        }

        if (isServed) {
          return 2;
        }

        return 3;
      }

      return getPriority(a).compareTo(getPriority(b));
    });

    _onSearchChanged();
  }

  // ------------------------------------------------------------
  // SERVE / UNSERVE
  // ------------------------------------------------------------

  Future<void> _handleServe(
    String uniqueId,
    bool currentValue,
    Map<String, dynamic> studentData,
  ) async {
    final String? vId = studentData['voteId']?.toString();

    final String sId = studentData['studentId']?.toString() ?? "";

    final String executionTrackingId = (vId != null && vId.isNotEmpty)
        ? vId
        : sId;

    if (executionTrackingId.isEmpty) {
      _showSnackBar("Invalid transaction target profile", Colors.red);
      return;
    }

    if (processingId != null) {
      return;
    }

    setState(() {
      processingId = uniqueId;
    });

    try {
      final String formattedDate = DateFormat(
        'dd/MM/yyyy',
      ).format(selectedDate);

      /*
       * EXISTING SERVE API — UNCHANGED.
       */
      final res = await api.updateServeStatus(
        (vId != null && vId.isNotEmpty) ? vId : "",
        sId,
        formattedDate,
        selectedTime,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final bool serverStatus = res['isServed'] ?? !currentValue;

        final String resolvedMealType = res['mealType']?.toString() ?? "Served";

        final String? returnedVoteId = res['voteId']?.toString();

        setState(() {
          final int masterIndex = _allVotes.indexWhere(
            (v) =>
                (v['voteId']?.toString() == uniqueId && uniqueId.isNotEmpty) ||
                (v['studentId']?.toString() == sId && sId.isNotEmpty),
          );

          if (masterIndex != -1) {
            _allVotes[masterIndex]['isServed'] = serverStatus;

            if (returnedVoteId != null && returnedVoteId.isNotEmpty) {
              _allVotes[masterIndex]['voteId'] = returnedVoteId;

              _allVotes[masterIndex]['choice'] = resolvedMealType;
            }
          }

          _sortAndFilterList();

          processingId = null;
        });

        // ------------------------------------------------------
        // NOTIFICATION
        // ------------------------------------------------------

        if (serverStatus && sId.isNotEmpty) {
          try {
            final String studentName = (studentData['studentName'] ?? "Student")
                .toString();

            final String mealChoice =
                (resolvedMealType.isNotEmpty && resolvedMealType != "Served")
                ? resolvedMealType
                : (studentData['choice']?.toString().isNotEmpty == true
                      ? studentData['choice'].toString()
                      : baseRoutineMenu);

            final notificationResponse = await api.createMealServedNotification(
              studentId: sId,
              meal: mealChoice,
              timeSlot: selectedTime,
              mealDate: formattedDate,
            );

            if (notificationResponse['success'] == true) {
              debugPrint(
                "Take Your Meal notification "
                "created for $studentName",
              );
            } else {
              debugPrint(
                "Notification creation failed: "
                "${notificationResponse['message']}",
              );
            }
          } catch (notificationError) {
            /*
             * Notification failure must never
             * undo a successful meal serving.
             */
            debugPrint(
              "Backend notification error: "
              "$notificationError",
            );
          }
        }

        _showSnackBar(
          res['message'] ?? (serverStatus ? "Meal served!" : "Status updated"),
          serverStatus ? Colors.green : Colors.orange,
        );
      } else {
        setState(() {
          processingId = null;
        });

        _showSnackBar(res['message'] ?? "Server rejected update", Colors.red);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        processingId = null;
      });

      _showSnackBar("Connection Error: $e", Colors.red);
    }
  }

  // ------------------------------------------------------------
  // FULL SCREEN STUDENT PHOTO
  // ------------------------------------------------------------

  void _showFullScreenImage(String imageUrl, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.95),
                ),
              ),

              InteractiveViewer(
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 80,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Failed to load photo",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    );
                  },
                ),
              ),

              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // CHOICE ICON
  // ------------------------------------------------------------

  IconData _getChoiceIcon(String choice) {
    final String c = choice.toLowerCase();

    if (c.contains("chicken")) {
      return Icons.kebab_dining_rounded;
    }

    if (c.contains("egg")) {
      return Icons.egg_rounded;
    }

    if (c.contains("fish")) {
      return Icons.set_meal_rounded;
    }

    if (c.contains("mutton")) {
      return Icons.dinner_dining_rounded;
    }

    if (c.contains("paneer")) {
      return Icons.bakery_dining_rounded;
    }

    return Icons.grass_rounded;
  }

  // ------------------------------------------------------------
  // CHOICE COLOR
  // ------------------------------------------------------------

  Color _getChoiceColor(String choice) {
    final String c = choice.toLowerCase();

    if (c.contains("chicken") || c.contains("mutton")) {
      return Colors.red.shade700;
    }

    if (c.contains("egg")) {
      return Colors.amber.shade800;
    }

    if (c.contains("fish")) {
      return Colors.blue.shade700;
    }

    return Colors.green.shade700;
  }

  // ------------------------------------------------------------
  // SNACKBAR
  // ------------------------------------------------------------

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      appBar: AppBar(
        title: const Text(
          "Serve Student Meals",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Column(
        children: [
          _buildFilters(),
          _buildSummarySection(),
          _buildSearchBar(),
          const Divider(height: 1),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: Colors.orange,
                    child: _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH BAR
  // ------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search student name...",
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.orange, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.orange.withOpacity(0.05),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  Widget _buildFilters() {
    final Color menuAccentColor = _getChoiceColor(baseRoutineMenu);

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange.withOpacity(0.1),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );

                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });

                      _fetchData();
                    }
                  },
                ),
              ),

              const SizedBox(width: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(color: Colors.orange),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTime,
                    items: ["Morning", "Night"]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedTime = val;
                        });

                        _fetchData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          if (!isLoading) ...[
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: menuAccentColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getChoiceIcon(baseRoutineMenu),
                    color: menuAccentColor,
                    size: 16,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    "CURRENT BASE MENU: ",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  Text(
                    "${baseRoutineMenu.toUpperCase()} ",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: menuAccentColor,
                    ),
                  ),

                  const SizedBox(width: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: menuAccentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "MEAL #$mealSequenceNumber",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          _buildCounterCard(
            "SERVED",
            servedCount.toString(),
            Colors.green,
            Icons.check_circle_outline,
          ),

          const SizedBox(width: 12),

          _buildCounterCard(
            "PENDING VOTES",
            notServedCount.toString(),
            Colors.orange,
            Icons.pending_actions,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // COUNTER CARD
  // ------------------------------------------------------------

  Widget _buildCounterCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.8),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Icon(icon, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // STUDENT LIST
  // ------------------------------------------------------------

  Widget _buildList() {
    if (_filteredVotes.isEmpty) {
      return const Center(
        child: Text(
          "No operational records logged",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredVotes.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, i) {
        final Map<String, dynamic> vote = Map<String, dynamic>.from(
          _filteredVotes[i],
        );

        final String uniqueId =
            vote['voteId']?.toString() ??
            vote['studentId']?.toString() ??
            vote['_id']?.toString() ??
            "";

        final bool served = vote['isServed'] == true;

        final bool isThisItemLoading = processingId == uniqueId;

        final String choiceStr = vote['choice']?.toString() ?? "";

        final bool hasVoted = choiceStr.isNotEmpty;

        final bool isGuest = vote['isGuest'] == true;

        final String currentChoice = hasVoted ? choiceStr : baseRoutineMenu;

        final Color choiceColor = isGuest
            ? Colors.orange.shade800
            : _getChoiceColor(currentChoice);

        final String photoUrl = (vote['studentPhoto'] ?? "").toString();

        final String studentName = (vote['studentName'] ?? "Unknown Student")
            .toString();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: served ? 0 : 1,
          clipBehavior: Clip.antiAlias,
          color: isGuest
              ? Colors.orange.shade50.withOpacity(0.3)
              : (served ? Colors.green.withOpacity(0.04) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: served
                  ? Colors.green.withOpacity(0.2)
                  : (isGuest
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.grey.shade100),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),

            // --------------------------------------------------
            // PHOTO
            // --------------------------------------------------
            leading: GestureDetector(
              onTap: photoUrl.isNotEmpty
                  ? () => _showFullScreenImage(photoUrl, studentName)
                  : null,
              child: MouseRegion(
                cursor: photoUrl.isNotEmpty
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: CircleAvatar(
                  backgroundColor: served
                      ? Colors.green.shade100
                      : (isGuest
                            ? Colors.orange.shade100
                            : Colors.orange.shade50),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Icon(
                          isGuest
                              ? Icons.group_add
                              : _getChoiceIcon(currentChoice),
                          color: served ? Colors.green : choiceColor,
                          size: 20,
                        )
                      : null,
                ),
              ),
            ),

            // --------------------------------------------------
            // NAME
            // --------------------------------------------------
            title: Text(
              studentName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: served ? TextDecoration.lineThrough : null,
                color: served ? Colors.grey : Colors.black87,
              ),
            ),

            // --------------------------------------------------
            // DETAILS
            // --------------------------------------------------
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),

                // Vote status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? Colors.blue.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasVoted ? "PRE-VOTED AT SYSTEM" : "WALK-IN ENTRANT",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: hasVoted
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // Choice
                Row(
                  children: [
                    Icon(
                      _getChoiceIcon(currentChoice),
                      color: served ? Colors.grey : choiceColor,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isGuest
                            ? "GUEST CHOICE: ${choiceStr.toUpperCase()}"
                            : (hasVoted
                                  ? "CHOICE: ${choiceStr.toUpperCase()}"
                                  : "NOT VOTED (WALK-IN: ${baseRoutineMenu.toUpperCase()})"),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: served ? Colors.grey : choiceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                // ------------------------------------------------
                // COMPACT MEAL PACK STATUS
                // ------------------------------------------------
                if (!isGuest) _buildMealPackBadge(vote),
              ],
            ),

            // --------------------------------------------------
            // SERVE SWITCH
            // --------------------------------------------------
            trailing: isThisItemLoading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    ),
                  )
                : Switch(
                    value: served,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.shade200,
                    onChanged: (val) => _handleServe(uniqueId, served, vote),
                  ),
          ),
        );
      },
    );
  }
}
