import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ApiService api = ApiService();

  // ===========================================================================
  // THEME COLORS
  // ===========================================================================

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

  Color get _divider => Theme.of(context).dividerColor;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Semantic colors
  static const Color green = Color(0xFF16A05D);
  static const Color orange = Color(0xFFD97706);
  static const Color red = Color(0xFFDC2626);
  static const Color blue = Color(0xFF2563EB);

  // ===========================================================================
  // PERSONAL HISTORY
  // ===========================================================================

  bool isLoading = true;
  List<dynamic> history = [];

  // ===========================================================================
  // CYCLES
  // ===========================================================================

  bool isCycleLoading = true;
  List<dynamic> cycles = [];
  int selectedCycleIndex = 0;

  // ===========================================================================
  // WHOLE MESS
  // ===========================================================================

  bool isWholeMessLoading = false;

  // Raw scheduled occurrences.
  //
  // This includes cancelled meals.
  final Map<String, int> wholeMessScheduled = {
    'chicken': 0,
    'egg': 0,
    'fish': 0,
    'veg': 0,
  };

  // Final total after removing cancelled meals.
  final Map<String, int> wholeMessTotal = {
    'chicken': 0,
    'egg': 0,
    'fish': 0,
    'veg': 0,
  };

  final Map<String, int> wholeMessServed = {
    'chicken': 0,
    'egg': 0,
    'fish': 0,
    'veg': 0,
  };

  final Map<String, int> wholeMessMissed = {
    'chicken': 0,
    'egg': 0,
    'fish': 0,
    'veg': 0,
  };

  final Map<String, int> wholeMessFuture = {
    'chicken': 0,
    'egg': 0,
    'fish': 0,
    'veg': 0,
  };

  final Map<String, int> wholeMessCancelled = {
    'chicken': 0,
    'egg': 0,
    'fish': 0,
    'veg': 0,
  };

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  // ===========================================================================
  // LOAD PAGE
  // ===========================================================================

  Future<void> _loadPage() async {
    await Future.wait([_fetchHistory(), _fetchCycles()]);
  }

  // ===========================================================================
  // PERSONAL HISTORY
  // ===========================================================================

  Future<void> _fetchHistory({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final response = await api.getVoteHistory();

      if (!mounted) return;

      final dynamic rawHistory = response['history'];

      setState(() {
        history = rawHistory is List ? List<dynamic>.from(rawHistory) : [];
        isLoading = false;
      });
    } catch (e) {
      debugPrint('History error: $e');

      if (!mounted) return;

      setState(() {
        history = [];
        isLoading = false;
      });

      _showSnackBar('Failed to load meal history', isError: true);
    }
  }

  // ===========================================================================
  // FETCH CYCLES
  // ===========================================================================

  Future<void> _fetchCycles() async {
    if (mounted) {
      setState(() {
        isCycleLoading = true;
      });
    }

    try {
      final response = await api.getMealCycleDateBounds();

      dynamic rawCycles;

      if (response['data'] is List) {
        rawCycles = response['data'];
      } else if (response['cycles'] is List) {
        rawCycles = response['cycles'];
      } else if (response['mealCycles'] is List) {
        rawCycles = response['mealCycles'];
      } else {
        rawCycles = [];
      }

      if (rawCycles is! List || rawCycles.isEmpty) {
        if (!mounted) return;

        setState(() {
          cycles = [];
          selectedCycleIndex = 0;
          isCycleLoading = false;
        });

        return;
      }

      final List<dynamic> loadedCycles = List<dynamic>.from(rawCycles);

      // Oldest -> newest.
      loadedCycles.sort((a, b) {
        final DateTime dateA = _parseDate(
          a is Map ? (a['startDateStr'] ?? a['startDate'] ?? a['start']) : null,
        );

        final DateTime dateB = _parseDate(
          b is Map ? (b['startDateStr'] ?? b['startDate'] ?? b['start']) : null,
        );

        return dateA.compareTo(dateB);
      });

      int newSelectedIndex = 0;

      // Prefer explicitly active cycle.
      for (int i = 0; i < loadedCycles.length; i++) {
        if (_isActiveCycle(loadedCycles[i])) {
          newSelectedIndex = i;
          break;
        }
      }

      // Otherwise select cycle containing today.
      if (!_isActiveCycle(loadedCycles[newSelectedIndex])) {
        final DateTime today = _today();

        for (int i = 0; i < loadedCycles.length; i++) {
          final DateTime start = _parseDate(_getCycleStart(loadedCycles[i]));

          final DateTime end = _parseDate(_getCycleEnd(loadedCycles[i]));

          if (_isValidDate(start) &&
              _isValidDate(end) &&
              !today.isBefore(start) &&
              !today.isAfter(end)) {
            newSelectedIndex = i;
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        cycles = loadedCycles;
        selectedCycleIndex = newSelectedIndex;
        isCycleLoading = false;
      });

      await _calculateWholeMessForSelectedCycle();
    } catch (e) {
      debugPrint('Cycle error: $e');

      if (!mounted) return;

      setState(() {
        cycles = [];
        selectedCycleIndex = 0;
        isCycleLoading = false;
      });

      _showSnackBar('Failed to load meal cycles', isError: true);
    }
  }

  // ===========================================================================
  // WHOLE MESS CALCULATION
  //
  // RAW SCHEDULE:
  //   Scheduled = Served + Missed + Future + Cancelled
  //
  // FINAL TOTAL:
  //   Total = Scheduled - Cancelled
  //
  // Therefore:
  //   Total = Served + Missed + Future
  //
  // Done:
  //   Done = Served + Missed
  //
  // Left:
  //   Left = Total - Done
  //        = Future
  //
  // Cancelled meals never become Served, Missed or Future.
  // ===========================================================================

  Future<void> _calculateWholeMessForSelectedCycle() async {
    if (cycles.isEmpty ||
        selectedCycleIndex < 0 ||
        selectedCycleIndex >= cycles.length) {
      _resetWholeMessStats();
      return;
    }

    final dynamic cycle = cycles[selectedCycleIndex];

    final String startDate = _getCycleStart(cycle);
    final String endDate = _getCycleEnd(cycle);

    if (startDate.isEmpty || endDate.isEmpty) {
      _resetWholeMessStats();
      return;
    }

    if (mounted) {
      setState(() {
        isWholeMessLoading = true;
        _resetWholeMessStats();
      });
    }

    try {
      // Fetch COMPLETE cycle.
      //
      // Future meals must be included.
      final dynamic response = await api.getAllMeals(
        startDate: startDate,
        endDate: endDate,
      );

      final List<dynamic> meals = _extractMeals(response);

      debugPrint('================================================');
      debugPrint('WHOLE MESS CALCULATION');
      debugPrint('Cycle: $startDate -> $endDate');
      debugPrint('Today: ${DateFormat('dd/MM/yyyy').format(_today())}');
      debugPrint('Daily meal documents: ${meals.length}');
      debugPrint('================================================');

      final Map<String, int> scheduled = {
        'chicken': 0,
        'egg': 0,
        'fish': 0,
        'veg': 0,
      };

      final Map<String, int> total = {
        'chicken': 0,
        'egg': 0,
        'fish': 0,
        'veg': 0,
      };

      final Map<String, int> served = {
        'chicken': 0,
        'egg': 0,
        'fish': 0,
        'veg': 0,
      };

      final Map<String, int> missed = {
        'chicken': 0,
        'egg': 0,
        'fish': 0,
        'veg': 0,
      };

      final Map<String, int> future = {
        'chicken': 0,
        'egg': 0,
        'fish': 0,
        'veg': 0,
      };

      final Map<String, int> cancelled = {
        'chicken': 0,
        'egg': 0,
        'fish': 0,
        'veg': 0,
      };

      final DateTime today = _today();

      final DateTime cycleStart = _parseDate(startDate);
      final DateTime cycleEnd = _parseDate(endDate);

      // =====================================================================
      // EVERY DAILY MEAL DOCUMENT
      // =====================================================================

      for (final dynamic dailyMeal in meals) {
        if (dailyMeal is! Map) {
          continue;
        }

        final DateTime mealDate = _parseDate(
          dailyMeal['date'] ?? dailyMeal['mealDate'] ?? dailyMeal['dateStr'],
        );

        if (!_isValidDate(mealDate)) {
          debugPrint(
            'Skipping meal with invalid date: '
            '${dailyMeal['date']}',
          );
          continue;
        }

        final DateTime day = DateTime(
          mealDate.year,
          mealDate.month,
          mealDate.day,
        );

        // Cycle range safety.
        if (_isValidDate(cycleStart)) {
          final DateTime start = DateTime(
            cycleStart.year,
            cycleStart.month,
            cycleStart.day,
          );

          if (day.isBefore(start)) {
            continue;
          }
        }

        if (_isValidDate(cycleEnd)) {
          final DateTime end = DateTime(
            cycleEnd.year,
            cycleEnd.month,
            cycleEnd.day,
          );

          if (day.isAfter(end)) {
            continue;
          }
        }

        // MORNING
        _processWholeMessSlot(
          slot: dailyMeal['morning'],
          mealDate: day,
          today: today,
          scheduled: scheduled,
          total: total,
          served: served,
          missed: missed,
          future: future,
          cancelled: cancelled,
          timeSlot: 'morning',
        );

        // NIGHT
        _processWholeMessSlot(
          slot: dailyMeal['night'],
          mealDate: day,
          today: today,
          scheduled: scheduled,
          total: total,
          served: served,
          missed: missed,
          future: future,
          cancelled: cancelled,
          timeSlot: 'night',
        );
      }

      // =====================================================================
      // DEBUG SUMMARY
      // =====================================================================

      debugPrint('---------------- WHOLE MESS ----------------');

      for (final String category in scheduled.keys) {
        final int scheduledCount = scheduled[category] ?? 0;

        final int cancelledCount = cancelled[category] ?? 0;

        final int totalCount = scheduledCount - cancelledCount;

        final int servedCount = served[category] ?? 0;

        final int missedCount = missed[category] ?? 0;

        final int futureCount = future[category] ?? 0;

        final int doneCount = servedCount + missedCount;

        final int leftCount = totalCount - doneCount;

        debugPrint(
          '$category -> '
          'scheduled=$scheduledCount, '
          'served=$servedCount, '
          'missed=$missedCount, '
          'future=$futureCount, '
          'cancelled=$cancelledCount, '
          'total=$totalCount, '
          'done=$doneCount, '
          'left=$leftCount',
        );
      }

      debugPrint('---------------------------------------------');

      if (!mounted) return;

      setState(() {
        wholeMessScheduled
          ..['chicken'] = scheduled['chicken'] ?? 0
          ..['egg'] = scheduled['egg'] ?? 0
          ..['fish'] = scheduled['fish'] ?? 0
          ..['veg'] = scheduled['veg'] ?? 0;

        wholeMessTotal
          ..['chicken'] = total['chicken'] ?? 0
          ..['egg'] = total['egg'] ?? 0
          ..['fish'] = total['fish'] ?? 0
          ..['veg'] = total['veg'] ?? 0;

        wholeMessServed
          ..['chicken'] = served['chicken'] ?? 0
          ..['egg'] = served['egg'] ?? 0
          ..['fish'] = served['fish'] ?? 0
          ..['veg'] = served['veg'] ?? 0;

        wholeMessMissed
          ..['chicken'] = missed['chicken'] ?? 0
          ..['egg'] = missed['egg'] ?? 0
          ..['fish'] = missed['fish'] ?? 0
          ..['veg'] = missed['veg'] ?? 0;

        wholeMessFuture
          ..['chicken'] = future['chicken'] ?? 0
          ..['egg'] = future['egg'] ?? 0
          ..['fish'] = future['fish'] ?? 0
          ..['veg'] = future['veg'] ?? 0;

        wholeMessCancelled
          ..['chicken'] = cancelled['chicken'] ?? 0
          ..['egg'] = cancelled['egg'] ?? 0
          ..['fish'] = cancelled['fish'] ?? 0
          ..['veg'] = cancelled['veg'] ?? 0;

        isWholeMessLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Whole mess calculation error: $e');

      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        isWholeMessLoading = false;
      });

      _showSnackBar('Could not calculate whole-mess meals', isError: true);
    }
  }

  // ===========================================================================
  // PROCESS ONE MEAL SLOT
  // ===========================================================================

  void _processWholeMessSlot({
    required dynamic slot,
    required DateTime mealDate,
    required DateTime today,
    required Map<String, int> scheduled,
    required Map<String, int> total,
    required Map<String, int> served,
    required Map<String, int> missed,
    required Map<String, int> future,
    required Map<String, int> cancelled,
    required String timeSlot,
  }) {
    if (slot == null || slot is! Map) {
      return;
    }

    // ========================================================================
    // MEAL TYPE
    // ========================================================================

    final String rawType =
        (slot['manu'] ??
                slot['menu'] ??
                slot['mealType'] ??
                slot['type'] ??
                slot['category'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    final String category = _normalizeMealType(rawType);

    if (!scheduled.containsKey(category)) {
      debugPrint('Ignoring unsupported meal type: $rawType');
      return;
    }

    // ========================================================================
    // EVERY VALID SLOT IS SCHEDULED
    //
    // This count includes cancelled meals.
    // ========================================================================

    scheduled[category] = (scheduled[category] ?? 0) + 1;

    // ========================================================================
    // CANCELLATION
    // ========================================================================

    final bool isCancelled =
        _isTrueValue(slot['isCancelled']) || _isTrueValue(slot['cancelled']);

    if (isCancelled) {
      cancelled[category] = (cancelled[category] ?? 0) + 1;

      debugPrint(
        '${DateFormat('dd/MM/yyyy').format(mealDate)} '
        '$timeSlot $category -> CANCELLED',
      );

      // IMPORTANT:
      // Cancelled meals do not enter total,
      // served, missed or future.
      return;
    }

    // ========================================================================
    // NON-CANCELLED TOTAL
    //
    // Total = Scheduled - Cancelled
    // ========================================================================

    total[category] = (total[category] ?? 0) + 1;

    final DateTime mealDay = DateTime(
      mealDate.year,
      mealDate.month,
      mealDate.day,
    );

    final DateTime currentDay = DateTime(today.year, today.month, today.day);

    // ========================================================================
    // FUTURE
    // ========================================================================

    if (mealDay.isAfter(currentDay)) {
      future[category] = (future[category] ?? 0) + 1;

      debugPrint(
        '${DateFormat('dd/MM/yyyy').format(mealDate)} '
        '$timeSlot $category -> FUTURE',
      );

      return;
    }

    // ========================================================================
    // REACHED MEAL
    // ========================================================================

    final bool isServed = _isWholeMessSlotServed(slot);

    if (isServed) {
      served[category] = (served[category] ?? 0) + 1;

      debugPrint(
        '${DateFormat('dd/MM/yyyy').format(mealDate)} '
        '$timeSlot $category -> SERVED',
      );
    } else {
      missed[category] = (missed[category] ?? 0) + 1;

      debugPrint(
        '${DateFormat('dd/MM/yyyy').format(mealDate)} '
        '$timeSlot $category -> MISSED',
      );
    }
  }

  // ===========================================================================
  // SERVED DETECTION
  // ===========================================================================

  bool _isWholeMessSlotServed(Map slot) {
    // Primary field.
    if (_isTrueValue(slot['isPrepared'])) {
      return true;
    }

    // Fallbacks.
    if (_isTrueValue(slot['prepared'])) {
      return true;
    }

    if (_isTrueValue(slot['isServed'])) {
      return true;
    }

    if (_isTrueValue(slot['served'])) {
      return true;
    }

    // Status.
    final String status = (slot['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (status == 'served' ||
        status == 'prepared' ||
        status == 'complete' ||
        status == 'completed' ||
        status == 'done') {
      return true;
    }

    // Nested preparation.
    final dynamic preparation = slot['preparation'];

    if (preparation is Map) {
      if (_isTrueValue(preparation['isPrepared'])) {
        return true;
      }

      if (_isTrueValue(preparation['prepared'])) {
        return true;
      }

      if (_isTrueValue(preparation['isServed'])) {
        return true;
      }
    }

    // Nested serving.
    final dynamic serving = slot['serving'];

    if (serving is Map) {
      if (_isTrueValue(serving['isServed'])) {
        return true;
      }

      if (_isTrueValue(serving['served'])) {
        return true;
      }
    }

    return false;
  }

  // ===========================================================================
  // FLEXIBLE BOOLEAN
  // ===========================================================================

  bool _isTrueValue(dynamic value) {
    if (value == true) {
      return true;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final String normalized = value.trim().toLowerCase();

      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'served' ||
          normalized == 'prepared' ||
          normalized == 'done' ||
          normalized == 'completed' ||
          normalized == 'complete';
    }

    return false;
  }

  // ===========================================================================
  // EXTRACT MEALS
  // ===========================================================================

  List<dynamic> _extractMeals(dynamic response) {
    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map) {
      final dynamic meals = response['meals'];

      if (meals is List) {
        return List<dynamic>.from(meals);
      }

      final dynamic data = response['data'];

      if (data is List) {
        return List<dynamic>.from(data);
      }

      if (data is Map) {
        if (data['meals'] is List) {
          return List<dynamic>.from(data['meals']);
        }
      }

      final dynamic results = response['results'];

      if (results is List) {
        return List<dynamic>.from(results);
      }

      final dynamic mealData = response['mealData'];

      if (mealData is List) {
        return List<dynamic>.from(mealData);
      }
    }

    return [];
  }

  // ===========================================================================
  // NORMALIZE MEAL TYPE
  // ===========================================================================

  String _normalizeMealType(String value) {
    final String normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'chicken':
      case 'chicken meal':
        return 'chicken';

      case 'egg':
      case 'egg meal':
        return 'egg';

      case 'fish':
      case 'fish meal':
        return 'fish';

      case 'veg':
      case 'vegetarian':
      case 'vegetable':
      case 'veg meal':
      case 'paneer':
      case 'paneer meal':
        return 'veg';

      default:
        return '';
    }
  }

  // ===========================================================================
  // RESET
  // ===========================================================================

  void _resetWholeMessStats() {
    wholeMessScheduled.updateAll((key, value) => 0);

    wholeMessTotal.updateAll((key, value) => 0);

    wholeMessServed.updateAll((key, value) => 0);

    wholeMessMissed.updateAll((key, value) => 0);

    wholeMessFuture.updateAll((key, value) => 0);

    wholeMessCancelled.updateAll((key, value) => 0);
  }

  // ===========================================================================
  // DONE
  // ===========================================================================

  int _done(String category) {
    return (wholeMessServed[category] ?? 0) + (wholeMessMissed[category] ?? 0);
  }

  // ===========================================================================
  // LEFT
  // ===========================================================================

  int _left(String category) {
    final int total = wholeMessTotal[category] ?? 0;

    final int done = _done(category);

    final int result = total - done;

    return result < 0 ? 0 : result;
  }

  // ===========================================================================
  // OVERALL COUNTS
  // ===========================================================================

  int get wholeMessScheduledCount {
    return wholeMessScheduled.values.fold(0, (sum, value) => sum + value);
  }

  int get wholeMessTotalCount {
    return wholeMessTotal.values.fold(0, (sum, value) => sum + value);
  }

  int get wholeMessServedCount {
    return wholeMessServed.values.fold(0, (sum, value) => sum + value);
  }

  int get wholeMessMissedCount {
    return wholeMessMissed.values.fold(0, (sum, value) => sum + value);
  }

  int get wholeMessFutureCount {
    return wholeMessFuture.values.fold(0, (sum, value) => sum + value);
  }

  int get wholeMessDoneCount {
    return wholeMessServedCount + wholeMessMissedCount;
  }

  int get wholeMessLeftCount {
    final int result = wholeMessTotalCount - wholeMessDoneCount;

    return result < 0 ? 0 : result;
  }

  int get wholeMessCancelledCount {
    return wholeMessCancelled.values.fold(0, (sum, value) => sum + value);
  }

  // ===========================================================================
  // CYCLE HELPERS
  // ===========================================================================

  String _getCycleStart(dynamic cycle) {
    if (cycle is! Map) {
      return '';
    }

    return (cycle['startDateStr'] ?? cycle['startDate'] ?? cycle['start'] ?? '')
        .toString();
  }

  String _getCycleEnd(dynamic cycle) {
    if (cycle is! Map) {
      return '';
    }

    return (cycle['endDateStr'] ?? cycle['endDate'] ?? cycle['end'] ?? '')
        .toString();
  }

  bool _isActiveCycle(dynamic cycle) {
    if (cycle is! Map) {
      return false;
    }

    return cycle['isCurrentActive'] == true ||
        cycle['isActive'] == true ||
        cycle['current'] == true;
  }

  String _cycleLabel(dynamic cycle) {
    if (cycle is! Map) {
      return 'Meal Cycle';
    }

    final dynamic label = cycle['label'];

    if (label != null && label.toString().trim().isNotEmpty) {
      return label.toString();
    }

    final DateTime start = _parseDate(_getCycleStart(cycle));

    final DateTime end = _parseDate(_getCycleEnd(cycle));

    if (_isValidDate(start) && _isValidDate(end)) {
      return '${DateFormat('dd MMM').format(start)}'
          ' - '
          '${DateFormat('dd MMM yyyy').format(end)}';
    }

    return 'Meal Cycle';
  }

  // ===========================================================================
  // DATE PARSER
  // ===========================================================================

  DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime(1900);
    }

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    final String raw = value.toString().trim();

    if (raw.isEmpty) {
      return DateTime(1900);
    }

    // DD/MM/YYYY
    final RegExp ddmmyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

    final Match? match = ddmmyyyy.firstMatch(raw);

    if (match != null) {
      final int day = int.tryParse(match.group(1)!) ?? 0;

      final int month = int.tryParse(match.group(2)!) ?? 0;

      final int year = int.tryParse(match.group(3)!) ?? 0;

      if (year > 0 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    // ISO.
    try {
      final DateTime parsed = DateTime.parse(raw);

      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return DateTime(1900);
    }
  }

  bool _isValidDate(DateTime date) {
    return date.year > 1900;
  }

  DateTime _today() {
    final DateTime now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  // ===========================================================================
  // PERSONAL HISTORY FOR SELECTED CYCLE
  // ===========================================================================

  List<dynamic> _historyForSelectedCycle() {
    if (cycles.isEmpty ||
        selectedCycleIndex < 0 ||
        selectedCycleIndex >= cycles.length) {
      return history;
    }

    final dynamic cycle = cycles[selectedCycleIndex];

    final DateTime start = _parseDate(_getCycleStart(cycle));

    final DateTime end = _parseDate(_getCycleEnd(cycle));

    if (!_isValidDate(start) || !_isValidDate(end)) {
      return history;
    }

    return history.where((entry) {
      if (entry is! Map) {
        return false;
      }

      final DateTime date = _parseDate(
        entry['date'] ?? entry['mealDate'] ?? entry['dateStr'],
      );

      if (!_isValidDate(date)) {
        return false;
      }

      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  // ===========================================================================
  // PERSONAL STATS
  // ===========================================================================

  int _votedCount(List<dynamic> records) {
    return records.where((item) {
      return item is Map && item['voted'] == true;
    }).length;
  }

  int _servedCount(List<dynamic> records) {
    return records.where((item) {
      return item is Map &&
          (item['isServed'] == true || item['served'] == true);
    }).length;
  }

  int _cancelledCount(List<dynamic> records) {
    return records.where((item) {
      return item is Map &&
          (item['isCancelled'] == true || item['cancelled'] == true);
    }).length;
  }

  int _missedCount(List<dynamic> records) {
    final int voted = _votedCount(records);

    final int cancelled = _cancelledCount(records);

    final int missed = records.length - voted - cancelled;

    return missed < 0 ? 0 : missed;
  }

  // ===========================================================================
  // DATE FORMAT
  // ===========================================================================

  String _formatDate(dynamic value) {
    final DateTime date = _parseDate(value);

    if (!_isValidDate(date)) {
      return value?.toString() ?? '';
    }

    return DateFormat('EEE, dd MMM yyyy').format(date);
  }

  String _formatVoteTime(dynamic value) {
    if (value == null) {
      return '';
    }

    try {
      final DateTime date = DateTime.parse(value.toString());

      return DateFormat('dd MMM, hh:mm a').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final dynamic selectedCycle =
        cycles.isNotEmpty &&
            selectedCycleIndex >= 0 &&
            selectedCycleIndex < cycles.length
        ? cycles[selectedCycleIndex]
        : null;

    final List<dynamic> cycleHistory = selectedCycle == null
        ? history
        : _historyForSelectedCycle();

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _loadPage,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              if (cycles.isNotEmpty)
                SliverToBoxAdapter(child: _buildCycleSelector()),

              if (cycles.isNotEmpty)
                SliverToBoxAdapter(child: _buildCycleBalanceCard()),

              SliverToBoxAdapter(child: _buildOverviewStats(cycleHistory)),

              SliverToBoxAdapter(
                child: _buildHistoryHeader(cycleHistory.length),
              ),

              if (isLoading || isCycleLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 55),
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  ),
                )
              else if (cycleHistory.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final dynamic item = cycleHistory[index];

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        index == 0 ? 0 : 6,
                        16,
                        index == cycleHistory.length - 1 ? 125 : 6,
                      ),
                      child: _buildHistoryCard(item),
                    );
                  }, childCount: cycleHistory.length),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, const Color(0xFF7168F3)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meal History',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your meals, organized by cycle',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _border),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _loadPage,
              icon: Icon(Icons.refresh_rounded, color: _primary, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CYCLE SELECTOR
  // ===========================================================================

  Widget _buildCycleSelector() {
    if (cycles.isEmpty) {
      return const SizedBox.shrink();
    }

    final dynamic cycle = cycles[selectedCycleIndex];

    final bool active = _isActiveCycle(cycle);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: GestureDetector(
        onTap: _showCycleSelector,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  color: _primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SELECTED CYCLE',
                          style: TextStyle(
                            fontSize: 8,
                            color: _textSecondary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: green.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _cycleLabel(cycle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WHOLE MESS CARD
  // ===========================================================================

  Widget _buildCycleBalanceCard() {
    final dynamic selectedCycle = cycles.isNotEmpty
        ? cycles[selectedCycleIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primary, _primaryDark],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.20),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WHOLE MESS MEALS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedCycle == null
                              ? 'Meal cycle'
                              : _cycleLabel(selectedCycle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isWholeMessLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 17),

              // =================================================================
              // TOTAL / DONE / LEFT / CANCELLED
              // =================================================================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTotalSummary(
                        'Total',
                        wholeMessTotalCount,
                        Icons.restaurant_menu_rounded,
                      ),
                    ),

                    _buildVerticalDivider(),

                    Expanded(
                      child: _buildTotalSummary(
                        'Done',
                        wholeMessDoneCount,
                        Icons.done_all_rounded,
                      ),
                    ),

                    _buildVerticalDivider(),

                    Expanded(
                      child: _buildTotalSummary(
                        'Left',
                        wholeMessLeftCount,
                        Icons.hourglass_bottom_rounded,
                      ),
                    ),

                    _buildVerticalDivider(),

                    Expanded(
                      child: _buildTotalSummary(
                        'Cancelled',
                        wholeMessCancelledCount,
                        Icons.cancel_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // =================================================================
              // FUTURE INFORMATION
              // =================================================================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${wholeMessFutureCount} future meals remaining in this cycle',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // =================================================================
              // CATEGORY CARDS
              // =================================================================
              Row(
                children: [
                  Expanded(
                    child: _buildWholeMessMeal(
                      title: 'Chicken',
                      category: 'chicken',
                      icon: Icons.kebab_dining_rounded,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _buildWholeMessMeal(
                      title: 'Egg',
                      category: 'egg',
                      icon: Icons.egg_rounded,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _buildWholeMessMeal(
                      title: 'Fish',
                      category: 'fish',
                      icon: Icons.set_meal_rounded,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _buildWholeMessMeal(
                      title: 'Veg',
                      category: 'veg',
                      icon: Icons.grass_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Colors.white60,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Total = all scheduled meals minus cancelled meals. Done = served + missed. Future meals remain in Left.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TOTAL SUMMARY
  // ===========================================================================

  Widget _buildTotalSummary(String title, int value, IconData icon) {
    return Column(
      children: [
        const Icon(Icons.circle, color: Colors.transparent, size: 0),
        Icon(icon, color: Colors.white70, size: 15),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 7,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 37,
      color: Colors.white.withOpacity(0.14),
    );
  }

  // ===========================================================================
  // CATEGORY CARD
  // ===========================================================================

  Widget _buildWholeMessMeal({
    required String title,
    required String category,
    required IconData icon,
  }) {
    final int total = wholeMessTotal[category] ?? 0;

    final int scheduled = wholeMessScheduled[category] ?? 0;

    final int served = wholeMessServed[category] ?? 0;

    final int missed = wholeMessMissed[category] ?? 0;

    final int future = wholeMessFuture[category] ?? 0;

    final int cancelled = wholeMessCancelled[category] ?? 0;

    final int done = served + missed;

    final int left = _left(category);

    return Container(
      padding: const EdgeInsets.fromLTRB(7, 10, 7, 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant, color: Colors.transparent, size: 0),
          Icon(icon, color: Colors.white, size: 18),

          const SizedBox(height: 5),

          // LEFT
          Text(
            '$left',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '$done / $total done',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            '$served served • $missed missed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.50),
              fontSize: 6.8,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            '$future future • $cancelled cancelled',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontSize: 6.4,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            '$scheduled scheduled',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PERSONAL OVERVIEW
  // ===========================================================================

  Widget _buildOverviewStats(List<dynamic> records) {
    final int voted = _votedCount(records);

    final int served = _servedCount(records);

    final int cancelled = _cancelledCount(records);

    final int missed = _missedCount(records);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR ACTIVITY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _textSecondary,
              letterSpacing: 0.9,
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Expanded(
                child: _buildSmallStat(
                  'Voted',
                  voted,
                  Icons.how_to_vote_rounded,
                  _primary,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _buildSmallStat(
                  'Served',
                  served,
                  Icons.check_circle_rounded,
                  green,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _buildSmallStat(
                  'Cancelled',
                  cancelled,
                  Icons.cancel_rounded,
                  red,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _buildSmallStat(
                  'Missed',
                  missed,
                  Icons.remove_circle_rounded,
                  orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),

          const SizedBox(height: 7),

          Text(
            '$value',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            style: TextStyle(
              fontSize: 8,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HISTORY HEADER
  // ===========================================================================

  Widget _buildHistoryHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meal Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your activity for the selected cycle',
                  style: TextStyle(fontSize: 10, color: _textSecondary),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$count ${count == 1 ? 'record' : 'records'}',
              style: TextStyle(
                color: _primary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 120),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 25),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: _primary,
                size: 30,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              'No Meal Records',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'There are no meal history records for this cycle yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PERSONAL HISTORY CARD
  // ===========================================================================

  Widget _buildHistoryCard(dynamic item) {
    if (item is! Map) {
      return const SizedBox.shrink();
    }

    final String menuItem = _extractMealItem(
      item['menuItem'] ??
          item['mealItem'] ??
          item['menu'] ??
          item['meal'] ??
          'Meal',
    );

    final String date = _formatDate(
      item['date'] ?? item['mealDate'] ?? item['dateStr'],
    );

    final String timeSlot = (item['timeSlot'] ?? item['mealTime'] ?? '')
        .toString()
        .toLowerCase();

    final bool cancelled =
        item['isCancelled'] == true || item['cancelled'] == true;

    final bool served = item['isServed'] == true || item['served'] == true;

    final bool voted = item['voted'] == true;

    final String voteTime = voted && item['votedAt'] != null
        ? _formatVoteTime(item['votedAt'])
        : '';

    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    if (cancelled) {
      statusColor = red;
      statusTitle = 'CANCELLED';
      statusIcon = Icons.cancel_rounded;
    } else if (served) {
      statusColor = green;
      statusTitle = 'SERVED';
      statusIcon = Icons.check_circle_rounded;
    } else if (voted) {
      statusColor = _primary;
      statusTitle = 'BOOKED';
      statusIcon = Icons.bookmark_added_rounded;
    } else {
      statusColor = orange;
      statusTitle = 'MISSED';
      statusIcon = Icons.remove_circle_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _isDark
                ? Colors.black.withOpacity(0.18)
                : Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(statusIcon, color: statusColor, size: 23),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuItem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: _textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        date,
                        style: TextStyle(
                          fontSize: 9,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                if (timeSlot.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        timeSlot.capitalize(),
                        style: TextStyle(
                          fontSize: 9,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                if (voteTime.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Voted $voteTime',
                          style: TextStyle(
                            fontSize: 9,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusTitle,
              style: TextStyle(
                color: statusColor,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MEAL ITEM EXTRACTOR
  // ===========================================================================

  String _extractMealItem(dynamic value) {
    if (value == null) {
      return 'Meal';
    }

    if (value is String) {
      final String text = value.trim();

      return text.isEmpty ? 'Meal' : text;
    }

    if (value is Map) {
      final dynamic name =
          value['name'] ??
          value['title'] ??
          value['meal'] ??
          value['menu'] ??
          value['item'] ??
          value['type'];

      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }

    return value.toString();
  }

  // ===========================================================================
  // CYCLE SELECTOR MODAL
  // ===========================================================================

  void _showCycleSelector() {
    if (cycles.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF4A4F5A)
                              : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Select Meal Cycle',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'View your meal history and whole-mess balance for a cycle.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: cycles.length,
                        itemBuilder: (context, index) {
                          final dynamic cycle = cycles[index];

                          final bool selected = index == selectedCycleIndex;

                          final bool isActive = _isActiveCycle(cycle);

                          final Color modalPrimary = Theme.of(
                            context,
                          ).colorScheme.primary;

                          final Color modalPrimarySoft =
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF292650)
                              : const Color(0xFFEEEEFF);

                          final Color modalBorder =
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2C303A)
                              : const Color(0xFFE7E7EF);

                          final Color modalText = Theme.of(
                            context,
                          ).colorScheme.onSurface;

                          final Color modalTextSecondary = Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              Navigator.pop(context);

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                selectedCycleIndex = index;
                              });

                              await _calculateWholeMessForSelectedCycle();

                              if (mounted) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? modalPrimarySoft
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? modalPrimary.withOpacity(0.25)
                                      : modalBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? modalPrimary
                                          : modalPrimarySoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      selected
                                          ? Icons.check_rounded
                                          : Icons.history_rounded,
                                      color: selected
                                          ? Colors.white
                                          : modalPrimary,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _cycleLabel(cycle),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? modalPrimary
                                                : modalText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isActive
                                              ? 'Currently active cycle'
                                              : 'Historical meal cycle',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: modalTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: green.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: green,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? red : green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ===========================================================================
// STRING EXTENSION
// ===========================================================================

extension _HistoryStringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }

    return '${this[0].toUpperCase()}'
        '${substring(1)}';
  }
}
