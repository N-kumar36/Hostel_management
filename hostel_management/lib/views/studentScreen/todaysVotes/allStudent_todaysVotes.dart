import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class AllStudentVotes extends StatefulWidget {
  const AllStudentVotes({super.key});

  @override
  State<AllStudentVotes> createState() => _AllStudentVotesState();
}

class _AllStudentVotesState extends State<AllStudentVotes> {
  final ApiService api = ApiService();

  // ============================================================
  // APP PALETTE
  // ============================================================

  static const Color primary = Color(0xFF5146E5);
  static const Color primaryDark = Color(0xFF4638D6);
  static const Color primarySoft = Color(0xFFEEEEFF);

  static const Color pageBackground = Color(0xFFF7F7FC);
  static const Color textPrimary = Color(0xFF181B2E);
  static const Color textSecondary = Color(0xFF74788B);
  static const Color border = Color(0xFFE7E7EF);

  static const Color orange = Color(0xFFFFA726);
  static const Color blue = Color(0xFF3867FF);
  static const Color red = Color(0xFFFF5252);
  static const Color teal = Color(0xFF10A6A0);
  static const Color green = Color(0xFF18A957);

  // ============================================================
  // STATE
  // ============================================================

  DateTime selectedDate = DateTime.now();
  String selectedTime = "Morning";

  bool isLoading = false;

  List<dynamic> studentVotes = [];
  List<dynamic> filteredVotes = [];

  int totalGuestPlates = 0;
  int totalStudentVotes = 0;

  String baseRoutineMenu = "veg";

  int regularChoiceCount = 0;
  int halalChoiceCount = 0;
  int eggChoiceCount = 0;
  int vegChoiceCount = 0;

  String searchQuery = "";
  String selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    _fetchVotes();
  }

  // ============================================================
  // FETCH
  // ============================================================

  Future<void> _fetchVotes() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final String formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);

    try {
      final response = await api.getDetailedVotesByDate(
        formattedDate,
        selectedTime,
      );

      if (!mounted) return;

      final List<dynamic> allFetchedData = response['data'] is List
          ? response['data']
          : [];

      String menu = "veg";

      if (allFetchedData.isNotEmpty &&
          allFetchedData.first['menuItem'] != null) {
        menu = allFetchedData.first['menuItem'].toString().toLowerCase().trim();
      }

      final List<dynamic> validVotes = allFetchedData.where((item) {
        final bool isGuest = item['isGuest'] == true;
        final String choice = item['choice']?.toString().trim() ?? "";

        return isGuest || choice.isNotEmpty;
      }).toList();

      int guests = 0;
      int students = 0;

      int regular = 0;
      int halal = 0;
      int egg = 0;
      int veg = 0;

      for (final item in validVotes) {
        final bool isGuest = item['isGuest'] == true;

        if (isGuest) {
          guests++;
          continue;
        }

        students++;

        final String choice =
            item['choice']?.toString().toLowerCase().trim() ?? "";

        switch (choice) {
          case 'regular':
            regular++;
            break;

          case 'halal_chicken':
            halal++;
            break;

          case 'egg_substitute':
            egg++;
            break;

          case 'veg_forced':
          case 'veg':
            veg++;
            break;
        }
      }

      setState(() {
        baseRoutineMenu = menu;

        studentVotes = validVotes;

        totalGuestPlates = guests;
        totalStudentVotes = students;

        regularChoiceCount = regular;
        halalChoiceCount = halal;
        eggChoiceCount = egg;
        vegChoiceCount = veg;

        isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showSnackBar("Unable to load voting records", red);
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _applyFilters() {
    final String query = searchQuery.trim().toLowerCase();

    final List<dynamic> results = studentVotes.where((item) {
      final bool isGuest = item['isGuest'] == true;

      final String name = item['studentName']?.toString().toLowerCase() ?? "";

      final String email = item['studentEmail']?.toString().toLowerCase() ?? "";

      final String choice = item['choice']?.toString().toLowerCase() ?? "";

      final bool matchesSearch =
          query.isEmpty || name.contains(query) || email.contains(query);

      if (!matchesSearch) return false;

      switch (selectedFilter) {
        case "Students":
          return !isGuest;

        case "Guests":
          return isGuest;

        case "Regular":
          return !isGuest && choice == "regular";

        case "Halal":
          return !isGuest && choice == "halal_chicken";

        case "Egg":
          return !isGuest && choice == "egg_substitute";

        case "Veg":
          return !isGuest && (choice == "veg" || choice == "veg_forced");

        default:
          return true;
      }
    }).toList();

    setState(() {
      filteredVotes = results;
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

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

    if (c.contains("veg")) {
      return Icons.grass_rounded;
    }

    return Icons.restaurant_rounded;
  }

  Color _getChoiceColor(String choice) {
    final String c = choice.toLowerCase();

    if (c.contains("chicken") || c.contains("mutton")) {
      return red;
    }

    if (c.contains("egg")) {
      return orange;
    }

    if (c.contains("fish")) {
      return blue;
    }

    if (c.contains("veg") || c.contains("paneer")) {
      return green;
    }

    if (c.contains("regular")) {
      return primary;
    }

    return textSecondary;
  }

  String _formatChoice(String choice) {
    switch (choice.toLowerCase()) {
      case 'regular':
        return 'REGULAR';

      case 'halal_chicken':
        return 'HALAL';

      case 'egg_substitute':
        return 'EGG SUBSTITUTE';

      case 'veg_forced':
        return 'VEG ALTERNATIVE';

      case 'veg':
        return 'VEG';

      default:
        if (choice.trim().isEmpty) {
          return 'UNKNOWN';
        }

        return choice.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _menuDisplayName() {
    switch (baseRoutineMenu.toLowerCase()) {
      case 'chicken':
        return 'Chicken';

      case 'fish':
        return 'Fish';

      case 'egg':
        return 'Egg';

      case 'mutton':
        return 'Mutton';

      case 'paneer':
        return 'Paneer';

      default:
        return 'Vegetarian';
    }
  }

  Color _menuColor() {
    switch (baseRoutineMenu.toLowerCase()) {
      case 'chicken':
      case 'mutton':
        return red;

      case 'fish':
        return blue;

      case 'egg':
        return orange;

      case 'paneer':
      case 'veg':
      default:
        return green;
    }
  }

  String _getInitials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return "?";

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return "${parts.first[0]}${parts.last[0]}".toUpperCase();
  }

  // ============================================================
  // NEW: DATE/TIME FORMATTER
  // ============================================================

  String _formatDateTime(dynamic value) {
    if (value == null) return "Unavailable";

    final raw = value.toString().trim();
    if (raw.isEmpty) return "Unavailable";

    final date = DateTime.tryParse(raw);
    if (date == null) return "Unavailable";

    final localDate = date.toLocal();

    return DateFormat('dd MMM yyyy • hh:mm a').format(localDate);
  }
  // ============================================================
  // NEW: TIME INFO
  // ============================================================

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final bool unavailable = value == "Unavailable" || value == "Not served";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: unavailable ? textSecondary : textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,

        titleSpacing: 18,

        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.poll_rounded, color: primary, size: 23),
            ),

            const SizedBox(width: 12),

            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Vote Registry",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Mess preparation dashboard",
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: isLoading ? null : _fetchVotes,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _fetchVotes,
        color: primary,

        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          slivers: [
            SliverToBoxAdapter(child: _buildHeaderSection()),

            if (isLoading)
              SliverFillRemaining(hasScrollBody: false, child: _buildLoading())
            else ...[
              SliverToBoxAdapter(child: _buildOverview()),

              SliverToBoxAdapter(child: _buildDistribution()),

              SliverToBoxAdapter(child: _buildSearchFilters()),

              _buildVoteList(),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderSection() {
    final Color menuColor = _menuColor();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: pageBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: primarySoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          DateFormat('dd MMMM yyyy').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          _buildTimeSelector(),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: menuColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: menuColor.withOpacity(0.13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: menuColor.withOpacity(0.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getChoiceIcon(baseRoutineMenu),
                    color: menuColor,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S MAIN MENU",
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                          color: menuColor,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _menuDisplayName(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: menuColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    selectedTime.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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
  // TIME SELECTOR
  // ============================================================

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pageBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTimeButton("Morning", Icons.wb_sunny_rounded)),
          Expanded(child: _buildTimeButton("Night", Icons.nightlight_round)),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String title, IconData icon) {
    final bool active = selectedTime == title;

    return GestureDetector(
      onTap: () {
        if (active) return;

        setState(() {
          selectedTime = title;
        });

        _fetchVotes();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? primary : textSecondary),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? primary : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _buildOverview() {
    final int total = totalStudentVotes + totalGuestPlates;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Preparation Overview",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primaryDark],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TOTAL PLATES",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "$total",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Plates to prepare for "
                        "${selectedTime.toLowerCase()}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildSmallStat(
                  "Students",
                  "$totalStudentVotes",
                  Icons.school_rounded,
                  blue,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildSmallStat(
                  "Guests",
                  "$totalGuestPlates",
                  Icons.groups_rounded,
                  orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISTRIBUTION
  // ============================================================

  Widget _buildDistribution() {
    final List<_ChoiceData> choices = [
      _ChoiceData(
        "Regular",
        regularChoiceCount,
        primary,
        Icons.restaurant_rounded,
      ),
    ];

    if (baseRoutineMenu.toLowerCase() == "chicken") {
      choices.add(
        _ChoiceData("Halal", halalChoiceCount, red, Icons.kebab_dining_rounded),
      );
    }

    if ([
      "chicken",
      "fish",
      "mutton",
      "paneer",
    ].contains(baseRoutineMenu.toLowerCase())) {
      choices.add(
        _ChoiceData(
          "Egg Substitute",
          eggChoiceCount,
          orange,
          Icons.egg_rounded,
        ),
      );
    }

    choices.add(
      _ChoiceData(
        "Veg Alternative",
        vegChoiceCount,
        green,
        Icons.grass_rounded,
      ),
    );

    final int maxCount = choices.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Choice Distribution",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ),

                Text(
                  "$totalStudentVotes students",
                  style: const TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ...choices.map(
              (choice) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _buildProgressRow(choice, maxCount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(_ChoiceData choice, int maxCount) {
    final double progress = choice.count / maxCount;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: choice.color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(choice.icon, size: 17, color: choice.color),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 88,
          child: Text(
            choice.title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),

        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: choice.color.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(choice.color),
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 30,
          child: Text(
            "${choice.count}",
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: choice.color,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchFilters() {
    const List<String> filters = [
      "All",
      "Students",
      "Guests",
      "Regular",
      "Halal",
      "Egg",
      "Veg",
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) {
              searchQuery = value;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: "Search student by name or email...",
              hintStyle: const TextStyle(fontSize: 12, color: textSecondary),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 21,
                color: textSecondary,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          searchQuery = "";
                        });
                        _applyFilters();
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 39,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final String filter = filters[index];

                final bool active = selectedFilter == filter;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedFilter = filter;
                    });

                    _applyFilters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: active ? primary : border),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Text(
                "Voting Records",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),

              const Spacer(),

              Text(
                "${filteredVotes.length} found",
                style: const TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildVoteList() {
    if (filteredVotes.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyVoteState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final dynamic item = filteredVotes[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildStudentCard(item),
          );
        }, childCount: filteredVotes.length),
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget _buildStudentCard(dynamic item) {
    final bool isGuest = item['isGuest'] == true;

    final String choice = item['choice']?.toString() ?? "";

    final Color choiceColor = _getChoiceColor(choice);

    final String name =
        item['studentName']?.toString() ??
        (isGuest ? "Guest" : "Unknown Student");

    final String email = item['studentEmail']?.toString() ?? "";

    final String photo = item['studentPhoto']?.toString() ?? "";

    final Color identityColor = isGuest ? orange : primary;

    // ============================================================
    // NEW TIMESTAMP DATA
    // ============================================================

    final bool isServed = item['isServed'] == true;

    final String votedTime = _formatDateTime(item['votedAt']);

    final String servedTime = isServed
        ? _formatDateTime(item['servedAt'])
        : "Not served";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isGuest ? orange.withOpacity(0.25) : border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(name: name, photo: photo, isGuest: isGuest),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isGuest
                                ? Colors.orange.shade900
                                : textPrimary,
                          ),
                        ),
                      ),

                      if (isGuest) ...[
                        const SizedBox(width: 7),
                        _buildTypeBadge("GUEST", orange),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    isGuest
                        ? "Approved guest plate"
                        : (email.isEmpty ? "Student" : email),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ==================================================
                  // CHOICE
                  // ==================================================
                  _buildChoiceBadge(choice, choiceColor),

                  const SizedBox(height: 9),

                  // ==================================================
                  // VOTE + SERVED TIMES
                  // ==================================================
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _buildTimeInfo(
                        icon: Icons.how_to_vote_rounded,
                        label: "VOTED",
                        value: votedTime,
                        color: primary,
                      ),

                      _buildTimeInfo(
                        icon: Icons.restaurant_rounded,
                        label: "SERVED",
                        value: servedTime,
                        color: isServed ? green : orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ========================================================
            // SERVED STATUS
            // ========================================================
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isServed ? green : identityColor).withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isServed ? Icons.check_circle_rounded : Icons.check_rounded,
                size: 18,
                color: isServed ? green : identityColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar({
    required String name,
    required String photo,
    required bool isGuest,
  }) {
    final Color color = isGuest ? orange : primary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.08),
          backgroundImage: (!isGuest && photo.isNotEmpty)
              ? NetworkImage(photo)
              : null,
          child: (!isGuest && photo.isNotEmpty)
              ? null
              : Text(
                  isGuest ? "G" : _getInitials(name),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
        ),

        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              isGuest ? Icons.groups_rounded : Icons.school_rounded,
              size: 9,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TYPE BADGE
  // ============================================================

  Widget _buildTypeBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ============================================================
  // CHOICE BADGE
  // ============================================================

  Widget _buildChoiceBadge(String choice, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getChoiceIcon(choice), size: 13, color: color),

          const SizedBox(width: 5),

          Text(
            _formatChoice(choice),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: primary),
          ),

          SizedBox(height: 15),

          Text(
            "Loading voting records...",
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: primary),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });

    _fetchVotes();
  }
}

// ============================================================
// CHOICE MODEL
// ============================================================

class _ChoiceData {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _ChoiceData(this.title, this.count, this.color, this.icon);
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyVoteState extends StatelessWidget {
  const _EmptyVoteState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 38,
                color: Color(0xFF5146E5),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "No voting records",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF181B2E),
              ),
            ),

            const SizedBox(height: 7),

            Text(
              "No active votes were found "
              "for this meal.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
