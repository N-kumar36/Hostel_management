import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/views/studentScreen/votes/vote_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyMealsPage extends StatefulWidget {
  const WeeklyMealsPage({super.key});

  @override
  State<WeeklyMealsPage> createState() => _WeeklyMealsPageState();
}

class _WeeklyMealsPageState extends State<WeeklyMealsPage> {
  final ApiService api = ApiService();

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primary = Color(0xFF5B4FE9);
  static const Color background = Color(0xFFF7F8FC);
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // ===========================================================================
  // STATE
  // ===========================================================================

  Future<Map<String, dynamic>> _mealsFuture = Future.value({});

  List<dynamic> _userVoteStatus = [];

  // Meals which are going to be voted.
  final Set<String> _selectedMeals = {};

  // Meals which are going to be cancelled.
  final Set<String> _selectedCancelMeals = {};

  // Regular / substitute preference for voting.
  final Map<String, String> _selectedPreferences = {};

  bool _isBulkVoting = false;
  bool _isBulkCancelling = false;

  bool get _isBulkAction => _isBulkVoting || _isBulkCancelling;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  // ===========================================================================
  // LOAD MEALS
  // ===========================================================================

  Future<void> _loadMeals() async {
    if (!mounted) return;

    setState(() {
      _selectedMeals.clear();
      _selectedCancelMeals.clear();
      _selectedPreferences.clear();
      _mealsFuture = api.fetchWeeklyMeals();
    });

    try {
      final meals = await _mealsFuture;

      if (!mounted) return;

      if (meals.isEmpty) {
        setState(() {
          _userVoteStatus = [];
        });
        return;
      }

      final ids = meals.values
          .whereType<Map>()
          .map((m) => m['_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (ids.isEmpty) {
        setState(() {
          _userVoteStatus = [];
        });
        return;
      }

      final status = await api.checkUserVotes(ids);

      if (!mounted) return;

      setState(() {
        _userVoteStatus = status;
      });
    } catch (e) {
      debugPrint('Weekly meal loading error: $e');

      if (!mounted) return;

      if (e.toString().contains('403')) {
        _showSnackBar('Account is not active. Voting disabled.', warning);
      }
    }
  }

  // ===========================================================================
  // VOTE INFO
  // ===========================================================================

  Map<String, dynamic>? _getVoteInfo(String mealId, String slot) {
    try {
      final result = _userVoteStatus.firstWhere(
        (v) =>
            v is Map &&
            v['mealId']?.toString() == mealId &&
            v['timeSlot']?.toString().toLowerCase() == slot.toLowerCase(),
        orElse: () => null,
      );

      if (result == null || result is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(result);
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // SELECTION KEY
  // ===========================================================================

  String _selectionKey(String mealId, String slot) {
    return '${mealId}_${slot.toLowerCase()}';
  }

  // ===========================================================================
  // LOCK
  // ===========================================================================

  bool _isMealLocked(String date, Map<String, dynamic> meal) {
    if (meal['isLocked'] == true) {
      return true;
    }

    final lockTime = meal['lockTime']?.toString() ?? '';

    if (lockTime.isEmpty) {
      return false;
    }

    try {
      final mealDate = DateFormat('dd/MM/yyyy').parse(date);
      final parsedLock = DateTime.parse(lockTime);

      final actualLock = DateTime(
        mealDate.year,
        mealDate.month,
        mealDate.day,
        parsedLock.hour,
        parsedLock.minute,
      );

      return DateTime.now().isAfter(actualLock);
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // CAN SELECT FOR VOTING
  // ===========================================================================

  bool _canSelectMeal(
    String date,
    String mealId,
    String slot,
    Map<String, dynamic> meal,
  ) {
    final vote = _getVoteInfo(mealId, slot);

    // Already voted.
    if (vote != null) {
      return false;
    }

    // Cancelled meal.
    if (meal['isCancelled'] == true) {
      return false;
    }

    // Voting deadline passed.
    if (_isMealLocked(date, meal)) {
      return false;
    }

    return true;
  }

  // ===========================================================================
  // CAN SELECT FOR CANCELLATION
  // ===========================================================================

  bool _canCancelMeal(
    String date,
    String mealId,
    String slot,
    Map<String, dynamic> meal,
  ) {
    final vote = _getVoteInfo(mealId, slot);

    // You can only cancel a meal you have voted for.
    if (vote == null) {
      return false;
    }

    // Already cancelled by manager.
    if (meal['isCancelled'] == true) {
      return false;
    }

    // Served meals cannot be cancelled.
    if (meal['isPrepared'] == true) {
      return false;
    }

    // Cancellation deadline passed.
    if (_isMealLocked(date, meal)) {
      return false;
    }

    return true;
  }

  // ===========================================================================
  // TOGGLE VOTE SELECTION
  // ===========================================================================

  void _toggleMeal(
    String date,
    String mealId,
    String slot,
    Map<String, dynamic> meal,
  ) {
    if (_isBulkAction) return;

    if (!_canSelectMeal(date, mealId, slot, meal)) {
      return;
    }

    final key = _selectionKey(mealId, slot);

    setState(() {
      // Keep voting and cancellation selections mutually exclusive.
      _selectedCancelMeals.clear();

      if (_selectedMeals.contains(key)) {
        _selectedMeals.remove(key);
        _selectedPreferences.remove(key);
      } else {
        _selectedMeals.add(key);
        _selectedPreferences[key] = 'regular';
      }
    });
  }

  // ===========================================================================
  // TOGGLE CANCELLATION SELECTION
  // ===========================================================================

  void _toggleCancelMeal(
    String date,
    String mealId,
    String slot,
    Map<String, dynamic> meal,
  ) {
    if (_isBulkAction) return;

    if (!_canCancelMeal(date, mealId, slot, meal)) {
      return;
    }

    final key = _selectionKey(mealId, slot);

    setState(() {
      // Keep voting and cancellation selections mutually exclusive.
      _selectedMeals.clear();
      _selectedPreferences.clear();

      if (_selectedCancelMeals.contains(key)) {
        _selectedCancelMeals.remove(key);
      } else {
        _selectedCancelMeals.add(key);
      }
    });
  }

  // ===========================================================================
  // SELECT ALL AVAILABLE FOR VOTING
  // ===========================================================================

  void _selectAllAvailable(Map<String, dynamic> weekly) {
    if (_isBulkAction) return;

    final available = <String>{};

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        if (_canSelectMeal(entry.key, mealId, slot, meal)) {
          available.add(_selectionKey(mealId, slot));
        }
      }
    }

    if (available.isEmpty) {
      _showSnackBar('No meals available for selection.', warning);
      return;
    }

    final allSelected = available.every(_selectedMeals.contains);

    setState(() {
      _selectedCancelMeals.clear();

      if (allSelected) {
        _selectedMeals.removeAll(available);

        for (final key in available) {
          _selectedPreferences.remove(key);
        }
      } else {
        _selectedMeals.addAll(available);

        for (final key in available) {
          _selectedPreferences.putIfAbsent(key, () => 'regular');
        }
      }
    });
  }

  // ===========================================================================
  // CHECK ALL VOTING MEALS SELECTED
  // ===========================================================================

  bool _areAllSelected(Map<String, dynamic> weekly) {
    final available = <String>{};

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        if (_canSelectMeal(entry.key, mealId, slot, meal)) {
          available.add(_selectionKey(mealId, slot));
        }
      }
    }

    return available.isNotEmpty && available.every(_selectedMeals.contains);
  }

  // ===========================================================================
  // SELECT ALL CANCELLABLE MEALS
  // ===========================================================================

  void _selectAllCancellable(Map<String, dynamic> weekly) {
    if (_isBulkAction) return;

    final cancellable = <String>{};

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        if (_canCancelMeal(entry.key, mealId, slot, meal)) {
          cancellable.add(_selectionKey(mealId, slot));
        }
      }
    }

    if (cancellable.isEmpty) {
      _showSnackBar('No voted meals can be cancelled.', warning);
      return;
    }

    final allSelected = cancellable.every(_selectedCancelMeals.contains);

    setState(() {
      _selectedMeals.clear();
      _selectedPreferences.clear();

      if (allSelected) {
        _selectedCancelMeals.removeAll(cancellable);
      } else {
        _selectedCancelMeals.addAll(cancellable);
      }
    });
  }

  // ===========================================================================
  // CHECK ALL CANCELLABLE MEALS SELECTED
  // ===========================================================================

  bool _areAllCancellableSelected(Map<String, dynamic> weekly) {
    final cancellable = <String>{};

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        if (_canCancelMeal(entry.key, mealId, slot, meal)) {
          cancellable.add(_selectionKey(mealId, slot));
        }
      }
    }

    return cancellable.isNotEmpty &&
        cancellable.every(_selectedCancelMeals.contains);
  }

  // ===========================================================================
  // BULK VOTING
  // ===========================================================================

  Future<void> _voteAllSelected(Map<String, dynamic> weekly) async {
    if (_selectedMeals.isEmpty || _isBulkAction) {
      return;
    }

    final votes = <Map<String, String>>[];

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        final key = _selectionKey(mealId, slot);

        if (!_selectedMeals.contains(key)) {
          continue;
        }

        if (!_canSelectMeal(entry.key, mealId, slot, meal)) {
          continue;
        }

        votes.add({
          'key': key,
          'mealId': mealId,
          'slot': slot,
          'date': entry.key,
          'menu': meal['manu']?.toString() ?? 'Meal',
          'preference': _selectedPreferences[key] ?? 'regular',
        });
      }
    }

    if (votes.isEmpty) {
      _showSnackBar('No eligible meals selected.', warning);
      return;
    }

    final confirmed = await _showConfirmation(votes);

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBulkVoting = true;
    });

    int successCount = 0;
    int failedCount = 0;

    final votedKeys = <String>[];

    for (final vote in votes) {
      try {
        final response = await api.postVote({
          'mealId': vote['mealId'],
          'timeSlot': vote['slot'],
          'mealType': vote['preference'],
        });

        if (response['success'] == true) {
          successCount++;
          votedKeys.add(vote['key']!);
        } else {
          failedCount++;
        }
      } catch (e) {
        failedCount++;

        debugPrint('Vote error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      for (final key in votedKeys) {
        _selectedMeals.remove(key);
        _selectedPreferences.remove(key);
      }

      _isBulkVoting = false;
    });

    await _loadMeals();

    if (!mounted) return;

    if (failedCount == 0) {
      _showSnackBar(
        '$successCount meal'
        '${successCount == 1 ? '' : 's'} voted successfully.',
        success,
      );
    } else if (successCount > 0) {
      _showSnackBar(
        '$successCount succeeded, '
        '$failedCount failed.',
        warning,
      );
    } else {
      _showSnackBar('Unable to submit votes.', danger);
    }
  }

  // ===========================================================================
  // BULK CANCELLATION
  // ===========================================================================

  Future<void> _cancelSelected(Map<String, dynamic> weekly) async {
    if (_selectedCancelMeals.isEmpty || _isBulkAction) {
      return;
    }

    final cancellations = <Map<String, String>>[];

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        final key = _selectionKey(mealId, slot);

        if (!_selectedCancelMeals.contains(key)) {
          continue;
        }

        if (!_canCancelMeal(entry.key, mealId, slot, meal)) {
          continue;
        }

        final vote = _getVoteInfo(mealId, slot);

        cancellations.add({
          'key': key,
          'mealId': mealId,
          'slot': slot,
          'date': entry.key,
          'menu': meal['manu']?.toString() ?? 'Meal',
          'preference':
              vote?['mealType']?.toString() ??
              vote?['meal_type']?.toString() ??
              'regular',
        });
      }
    }

    if (cancellations.isEmpty) {
      _showSnackBar(
        'No eligible voted meals selected for cancellation.',
        warning,
      );
      return;
    }

    final confirmed = await _showCancelConfirmation(cancellations);

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBulkCancelling = true;
    });

    int successCount = 0;
    int failedCount = 0;

    final cancelledKeys = <String>[];

    for (final item in cancellations) {
      try {
        final response = await api.cancelVote(item['mealId']!, item['slot']!);

        if (response['success'] == true) {
          successCount++;
          cancelledKeys.add(item['key']!);
        } else {
          failedCount++;
        }
      } catch (e) {
        failedCount++;

        debugPrint('Cancel vote error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      for (final key in cancelledKeys) {
        _selectedCancelMeals.remove(key);
      }

      _isBulkCancelling = false;
    });

    await _loadMeals();

    if (!mounted) return;

    if (failedCount == 0) {
      _showSnackBar(
        '$successCount meal'
        '${successCount == 1 ? '' : 's'} cancelled successfully.',
        success,
      );
    } else if (successCount > 0) {
      _showSnackBar(
        '$successCount cancelled, '
        '$failedCount failed.',
        warning,
      );
    } else {
      _showSnackBar('Unable to cancel selected meals.', danger);
    }
  }

  // ===========================================================================
  // VOTE CONFIRMATION
  // ===========================================================================

  Future<bool?> _showConfirmation(List<Map<String, String>> votes) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Confirm Votes',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: votes.length,
              itemBuilder: (_, index) {
                final vote = votes[index];

                final slot = vote['slot'] == 'morning' ? 'Morning' : 'Night';

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      vote['slot'] == 'morning'
                          ? Icons.wb_sunny_rounded
                          : Icons.nightlight_rounded,
                      color: primary,
                      size: 17,
                    ),
                  ),
                  title: Text(
                    '$slot • ${vote['menu']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${vote['date']} • '
                    '${_formatPreference(vote['preference']!)}',
                    style: const TextStyle(fontSize: 10, color: textGrey),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text('VOTE ${votes.length}'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // CANCELLATION CONFIRMATION
  // ===========================================================================

  Future<bool?> _showCancelConfirmation(
    List<Map<String, String>> cancellations,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: danger.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: danger,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cancel Selected Meals?',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: danger.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 17, color: danger),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your selected meal votes will be '
                          'cancelled. You can vote again later '
                          'if the meal is still open.',
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cancellations.length,
                    itemBuilder: (_, index) {
                      final item = cancellations[index];

                      final slot = item['slot'] == 'morning'
                          ? 'Morning'
                          : 'Night';

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item['slot'] == 'morning'
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_rounded,
                            color: danger,
                            size: 17,
                          ),
                        ),
                        title: Text(
                          '$slot • ${item['menu']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${item['date']} • '
                          '${_formatPreference(item['preference']!)}',
                          style: const TextStyle(fontSize: 10, color: textGrey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'KEEP VOTES',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text('CANCEL ${cancellations.length}'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ALTERNATIVES
  // ===========================================================================

  bool _isNonVeg(String menu) {
    final value = menu.toLowerCase();

    return value.contains('chicken') ||
        value.contains('fish') ||
        value.contains('mutton');
  }

  List<String> _alternatives(String menu) {
    final value = menu.toLowerCase();

    // Chicken meal
    if (value.contains('chicken')) {
      return ['regular', 'halal_chicken', 'egg_substitute', 'veg_forced'];
    }

    // Egg meal
    if (value.contains('egg')) {
      return ['regular', 'veg_forced'];
    }

    // Fish / Mutton / Paneer
    if (value.contains('fish') ||
        value.contains('mutton') ||
        value.contains('paneer')) {
      return ['regular', 'egg_substitute', 'veg_forced'];
    }

    // Any other menu
    return ['regular'];
  }

  String _formatPreference(String value) {
    switch (value.toLowerCase()) {
      case 'regular':
        return 'Regular';

      case 'halal_chicken':
        return 'Halal Chicken';

      case 'egg_substitute':
        return 'Egg Substitute';

      case 'veg_forced':
        return 'Vegetarian';

      default:
        return value;
    }
  }

  // ===========================================================================
  // MENU-WISE PROGRESS
  // ===========================================================================

  Widget _buildMenuProgress(Map<String, dynamic> weekly) {
    final Map<String, int> total = {
      'Chicken': 0,
      'Egg': 0,
      'Fish': 0,
      'Mutton': 0,
      'Veg': 0,
    };

    final Map<String, int> voted = {
      'Chicken': 0,
      'Egg': 0,
      'Fish': 0,
      'Mutton': 0,
      'Veg': 0,
    };

    for (final entry in weekly.entries) {
      if (entry.value is! Map) continue;

      final mealData = Map<String, dynamic>.from(entry.value);

      final mealId = mealData['_id']?.toString() ?? '';

      if (mealId.isEmpty) continue;

      for (final slot in ['morning', 'night']) {
        final raw = mealData[slot];

        if (raw is! Map) continue;

        final meal = Map<String, dynamic>.from(raw);

        if (meal.isEmpty || meal['isCancelled'] == true) {
          continue;
        }

        final menu = meal['manu']?.toString() ?? '';

        final type = _menuType(menu);

        if (!total.containsKey(type)) {
          continue;
        }

        total[type] = total[type]! + 1;

        if (_getVoteInfo(mealId, slot) != null) {
          voted[type] = voted[type]! + 1;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE7E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.poll_rounded, size: 16, color: primary),
              SizedBox(width: 6),
              Text(
                'Meal progress',
                style: TextStyle(
                  color: textDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _progressChip('Chicken', voted['Chicken']!, total['Chicken']!),
                _progressChip('Egg', voted['Egg']!, total['Egg']!),
                _progressChip('Fish', voted['Fish']!, total['Fish']!),
                _progressChip('Mutton', voted['Mutton']!, total['Mutton']!),
                _progressChip('Veg', voted['Veg']!, total['Veg']!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressChip(String title, int voted, int total) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$title ',
              style: const TextStyle(
                color: textGrey,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: '$voted/$total',
              style: const TextStyle(
                color: textDark,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _menuType(String menu) {
    final value = menu.toLowerCase();

    if (value.contains('chicken')) {
      return 'Chicken';
    }

    if (value.contains('mutton')) {
      return 'Mutton';
    }

    if (value.contains('fish')) {
      return 'Fish';
    }

    if (value.contains('egg')) {
      return 'Egg';
    }

    return 'Veg';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _mealsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primary),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return _emptyState();
            }

            final weekly = snapshot.data!;

            final dates = weekly.keys.toList();

            dates.sort((a, b) {
              try {
                return DateFormat(
                  'dd/MM/yyyy',
                ).parse(a).compareTo(DateFormat('dd/MM/yyyy').parse(b));
              } catch (_) {
                return 0;
              }
            });

            final allSelected = _areAllSelected(weekly);

            final allCancelSelected = _areAllCancellableSelected(weekly);

            final hasSelections =
                _selectedMeals.isNotEmpty || _selectedCancelMeals.isNotEmpty;

            return RefreshIndicator(
              color: primary,
              onRefresh: _loadMeals,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildTopBar(weekly, allSelected, allCancelSelected),
                  ),

                  SliverToBoxAdapter(child: _buildMenuProgress(weekly)),

                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      2,
                      14,
                      hasSelections ? 15 : 20,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final date = dates[index];

                        final raw = weekly[date];

                        if (raw is! Map) {
                          return const SizedBox();
                        }

                        return _buildDayCard(
                          date,
                          Map<String, dynamic>.from(raw),
                        );
                      }, childCount: dates.length),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar:
          (_selectedMeals.isEmpty && _selectedCancelMeals.isEmpty)
          ? null
          : _buildBottomActionButton(),
    );
  }

  // ===========================================================================
  // TOP BAR
  // ===========================================================================

  Widget _buildTopBar(
    Map<String, dynamic> weekly,
    bool allSelected,
    bool allCancelSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 7),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Meals',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Choose or cancel your meals',
                  style: TextStyle(fontSize: 10, color: textGrey),
                ),
              ],
            ),
          ),

          // SELECT ALL VOTABLE
          TextButton(
            onPressed: _isBulkAction ? null : () => _selectAllAvailable(weekly),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
            child: Text(
              allSelected ? 'CLEAR' : 'SELECT ALL',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 9,
                color: primary,
              ),
            ),
          ),

          // MORE ACTIONS
          PopupMenuButton<String>(
            enabled: !_isBulkAction,
            tooltip: 'Meal selection options',
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: textGrey,
            ),
            onSelected: (value) {
              if (value == 'cancel') {
                _selectAllCancellable(weekly);
              } else if (value == 'clear') {
                setState(() {
                  _selectedMeals.clear();
                  _selectedCancelMeals.clear();
                  _selectedPreferences.clear();
                });
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'cancel',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_busy_rounded,
                        color: danger,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        allCancelSelected
                            ? 'Clear cancel selection'
                            : 'Select voted meals',
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded, color: textGrey, size: 19),
                      SizedBox(width: 9),
                      Text('Clear all selections'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DAY CARD
  // ===========================================================================

  Widget _buildDayCard(String date, Map<String, dynamic> mealData) {
    String day = date;
    String shortDate = '';

    try {
      final parsed = DateFormat('dd/MM/yyyy').parse(date);

      day = DateFormat('EEEE').format(parsed);

      shortDate = DateFormat('dd MMM').format(parsed);
    } catch (_) {}

    final mealId = mealData['_id']?.toString() ?? '';

    final morning = mealData['morning'] is Map
        ? Map<String, dynamic>.from(mealData['morning'])
        : <String, dynamic>{};

    final night = mealData['night'] is Map
        ? Map<String, dynamic>.from(mealData['night'])
        : <String, dynamic>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E8EE)),
      ),
      child: Column(
        children: [
          // DAY HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 9, 7, 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        day,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        shortDate,
                        style: const TextStyle(color: textGrey, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),

                // DETAILS
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isBulkAction
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VotePage(
                                id: mealId,
                                date: date,
                                morning: morning,
                                night: night,
                              ),
                            ),
                          ).then((_) => _loadMeals());
                        },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F1F5)),

          // MORNING
          _buildMealRow(
            date: date,
            mealId: mealId,
            slot: 'morning',
            label: 'Morning',
            icon: Icons.wb_sunny_rounded,
            color: warning,
            meal: morning,
          ),

          // NIGHT
          _buildMealRow(
            date: date,
            mealId: mealId,
            slot: 'night',
            label: 'Night',
            icon: Icons.nightlight_rounded,
            color: primary,
            meal: night,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MEAL ROW
  // ===========================================================================

  Widget _buildMealRow({
    required String date,
    required String mealId,
    required String slot,
    required String label,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> meal,
  }) {
    if (meal.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 17),
            const SizedBox(width: 8),
            Text(
              '$label unavailable',
              style: const TextStyle(color: textGrey, fontSize: 10),
            ),
          ],
        ),
      );
    }

    final vote = _getVoteInfo(mealId, slot);

    final bool voted = vote != null;

    final bool cancelled = meal['isCancelled'] == true;

    final bool locked = _isMealLocked(date, meal);

    final bool served = meal['isPrepared'] == true;

    final bool selectable = _canSelectMeal(date, mealId, slot, meal);

    final bool cancelSelectable = _canCancelMeal(date, mealId, slot, meal);

    final key = _selectionKey(mealId, slot);

    final bool selectedForVote = _selectedMeals.contains(key);

    final bool selectedForCancel = _selectedCancelMeals.contains(key);

    final bool selected = selectedForVote || selectedForCancel;

    final menu = meal['manu']?.toString() ?? 'Meal';

    final nonVeg = _isNonVeg(menu);

    final preference = _selectedPreferences[key] ?? 'regular';

    final selectionColor = selectedForCancel ? danger : primary;

    return InkWell(
      onTap: _isBulkAction
          ? null
          : () {
              if (cancelSelectable) {
                _toggleCancelMeal(date, mealId, slot, meal);
              } else if (selectable) {
                _toggleMeal(date, mealId, slot, meal);
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          children: [
            Row(
              children: [
                // CHECKBOX
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? selectionColor : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? selectionColor
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 15,
                        )
                      : null,
                ),

                const SizedBox(width: 8),

                // ICON
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),

                const SizedBox(width: 8),

                // INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),

                          if (cancelled)
                            _smallStatus('CANCELLED', danger)
                          else if (selectedForCancel)
                            _smallStatus('CANCEL SELECTED', danger)
                          else if (voted)
                            _smallStatus('VOTED', success)
                          else if (served)
                            _smallStatus('SERVED', success)
                          else if (locked)
                            _smallStatus('CLOSED', warning)
                          else if (selectedForVote)
                            _smallStatus('SELECTED', primary),
                        ],
                      ),

                      const SizedBox(height: 2),

                      Text(
                        menu,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedForCancel
                              ? danger.withOpacity(0.75)
                              : selectable || cancelSelectable
                              ? textGrey
                              : const Color(0xFF9CA3AF),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // SELECT / CANCEL ICON
                if (cancelSelectable)
                  Icon(
                    selectedForCancel
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: selectedForCancel
                        ? danger
                        : danger.withOpacity(0.55),
                    size: 18,
                  )
                else if (selectable)
                  Icon(
                    selectedForVote
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: selectedForVote ? primary : const Color(0xFFB8BBC5),
                    size: 18,
                  ),
              ],
            ),

            // SUBSTITUTE
            // SUBSTITUTE / NON-VEG PREFERENCE
            if (selectedForVote && nonVeg)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 30),
                child: Row(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 15,
                        color: primary,
                      ),
                    ),

                    const SizedBox(width: 7),

                    const Text(
                      'Instead',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primary.withOpacity(0.10)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _alternatives(menu).contains(preference)
                                ? preference
                                : 'regular',

                            isExpanded: true,
                            isDense: true,

                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: primary,
                            ),

                            style: const TextStyle(
                              color: textDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),

                            items: _alternatives(menu).map((option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Row(
                                  children: [
                                    Icon(
                                      option == 'halal_chicken'
                                          ? Icons.workspace_premium_rounded
                                          : option == 'egg_substitute'
                                          ? Icons.egg_rounded
                                          : option == 'veg_forced'
                                          ? Icons.grass_rounded
                                          : Icons.restaurant_rounded,
                                      size: 15,
                                      color: option == 'halal_chicken'
                                          ? danger
                                          : option == 'egg_substitute'
                                          ? warning
                                          : option == 'veg_forced'
                                          ? success
                                          : primary,
                                    ),

                                    const SizedBox(width: 7),

                                    Expanded(
                                      child: Text(
                                        _formatPreference(option),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            onChanged: _isBulkAction
                                ? null
                                : (value) {
                                    if (value == null) return;

                                    setState(() {
                                      _selectedPreferences[key] = value;
                                    });
                                  },
                          ),
                        ),
                      ),
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
  // STATUS
  // ===========================================================================

  Widget _smallStatus(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 6.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BUTTON
  // ===========================================================================

  Widget _buildBottomActionButton() {
    final bool cancelling = _selectedCancelMeals.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8E9EF))),
        ),
        child: SizedBox(
          height: 45,
          child: ElevatedButton(
            onPressed: _isBulkAction
                ? null
                : () async {
                    final weekly = await _mealsFuture;

                    if (!mounted) {
                      return;
                    }

                    if (cancelling) {
                      await _cancelSelected(weekly);
                    } else {
                      await _voteAllSelected(weekly);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: cancelling ? danger : primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: (cancelling ? danger : primary)
                  .withOpacity(0.55),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: _isBulkAction
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cancelling
                            ? Icons.event_busy_rounded
                            : Icons.how_to_vote_rounded,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        cancelling
                            ? 'CANCEL ${_selectedCancelMeals.length} SELECTED MEALS'
                            : 'VOTE ${_selectedMeals.length} SELECTED MEALS',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _emptyState() {
    return RefreshIndicator(
      color: primary,
      onRefresh: _loadMeals,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu_rounded, size: 45, color: primary),
                  SizedBox(height: 12),
                  Text(
                    'No meals found',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'No meal schedule is available.',
                    style: TextStyle(color: textGrey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
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
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }
}
