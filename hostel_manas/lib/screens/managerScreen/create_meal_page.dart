import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealManagementPage extends StatefulWidget {
  final Map<String, dynamic>? existingMeal;
  const MealManagementPage({super.key, this.existingMeal});

  @override
  State<MealManagementPage> createState() => _MealManagementPageState();
}

class _MealManagementPageState extends State<MealManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final themeColor = const Color.fromARGB(255, 34, 211, 208);
  final api = ApiService();

  bool isLoading = false;
  bool isRoutineLoading = false;
  List<dynamic> meals = [];
  String? mealId;

  DateTime selectedDate = DateTime.now();
  String? selectedMorningMenu;
  String? selectedNightMenu;
  TimeOfDay morningLock = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay nightLock = const TimeOfDay(hour: 17, minute: 0);

  final List<String> menuOptions = [
    "veg",
    "egg",
    "paneer",
    "chicken",
    "fish",
    "mutton",
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// ✅ Logic: Fetch meals first to determine date prediction
  Future<void> _initData() async {
    await _fetchMeals();
    if (!mounted) return;

    if (widget.existingMeal != null) {
      _loadMealForEdit(widget.existingMeal!);
    } else {
      _autoSelectNextDate();
      await _fetchAndSetRoutine();
    }
  }

  /// ✅ UI Logic: Auto-select 1 day after the latest existing meal
  void _autoSelectNextDate() {
    if (meals.isEmpty) {
      setState(() => selectedDate = DateTime.now());
      return;
    }

    try {
      final dates =
          meals
              .map<DateTime>(
                (m) => DateFormat('dd/MM/yyyy').parse(m['date'] as String),
              )
              .toList()
            ..sort((a, b) => b.compareTo(a)); // latest first

      final latestDate = dates.first;
      setState(() {
        selectedDate = latestDate.add(const Duration(days: 1));
      });
    } catch (e) {
      debugPrint("Error parsing latest date: $e");
      setState(() => selectedDate = DateTime.now());
    }
  }

  Future<void> _fetchAndSetRoutine() async {
    setState(() => isRoutineLoading = true);
    try {
      final res = await api.getroutine();
      if (res['success'] == true && mounted) {
        final routine = res['weeklyRoutine']?['routine'];
        if (routine != null) {
          final dayKey = selectedDate.weekday.toString();
          final dayRoutine = routine[dayKey];
          if (dayRoutine != null) {
            setState(() {
              selectedMorningMenu = dayRoutine['morning'];
              selectedNightMenu = dayRoutine['night'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Routine fetch failed: $e");
    } finally {
      if (mounted) setState(() => isRoutineLoading = false);
    }
  }

  void _loadMealForEdit(Map<String, dynamic> meal) {
    setState(() {
      mealId = meal['_id'];
      selectedDate = DateFormat('dd/MM/yyyy').parse(meal['date']);
      selectedMorningMenu = meal['morning']['manu'];
      selectedNightMenu = meal['night']['manu'];
      morningLock = TimeOfDay.fromDateTime(
        DateTime.parse(meal['morning']['lockTime']),
      );
      nightLock = TimeOfDay.fromDateTime(
        DateTime.parse(meal['night']['lockTime']),
      );
    });
  }

  void _resetForm() {
    setState(() {
      mealId = null;
      selectedMorningMenu = null;
      selectedNightMenu = null;
    });
    _autoSelectNextDate();
    _fetchAndSetRoutine();
  }

  Future<void> _fetchMeals() async {
    setState(() => isLoading = true);
    try {
      final res = await api.getAllMeals();
      if (res['success'] == true && mounted) {
        setState(() => meals = (res['meals'] ?? []) as List<dynamic>);
      }
    } catch (e) {
      _showSnackBar("Error fetching meals: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleToggleCancel(
    String id,
    String slot,
    bool currentStatus,
  ) async {
    final action = currentStatus ? "Restore" : "Cancel";
    final confirm = await _showConfirmDialog(
      "$action ${slot.toUpperCase()}",
      "Are you sure you want to $action this meal?",
    );
    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final payload = {
        slot: {"isCancelled": !currentStatus},
      };
      final res = await api.updateMeal(id, payload);
      if (res['success'] == true) {
        _showSnackBar("${slot.toUpperCase()} status updated", Colors.green);
        _fetchMeals();
      }
    } catch (e) {
      _showSnackBar("Update failed: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (selectedMorningMenu == null || selectedNightMenu == null) {
      _showSnackBar("Select both menus", Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    // 1. Create the local DateTime objects
    final morningLockDT = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      morningLock.hour,
      morningLock.minute,
    );
    final nightLockDT = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      nightLock.hour,
      nightLock.minute,
    );

    final payload = {
      "date": DateFormat('dd/MM/yyyy').format(selectedDate),
      "morning": {
        "manu": selectedMorningMenu,
        // Use .toIso8601String() and manually add 'Z' to avoid timezone shifting
        "lockTime": "${morningLockDT.toIso8601String()}Z",
        "isCancelled": false,
      },
      "night": {
        "manu": selectedNightMenu,
        "lockTime": "${nightLockDT.toIso8601String()}Z",
        "isCancelled": false,
      },
    };

    try {
      final res = mealId != null
          ? await api.updateMeal(mealId!, payload)
          : await api.createMeal(payload);
      _showSnackBar(res['message'] ?? "Success!", Colors.green);
      _resetForm();
      _fetchMeals();
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Meal Management",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchAndSetRoutine,
            icon: const Icon(Icons.auto_awesome, color: Colors.blue),
          ),
          if (mealId != null)
            IconButton(
              onPressed: _resetForm,
              icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFormSection(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Existing Plans",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(child: _buildMealsList()),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: mealId != null
            ? Border.all(color: themeColor, width: 2)
            : null, // ✅ Edit Highlight
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildDateCard(),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildMealInput(
                    "Morning",
                    selectedMorningMenu,
                    morningLock,
                    (val) => setState(() => selectedMorningMenu = val),
                    true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMealInput(
                    "Night",
                    selectedNightMenu,
                    nightLock,
                    (val) => setState(() => selectedNightMenu = val),
                    false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealInput(
    String label,
    String? menuVal,
    TimeOfDay lockTime,
    Function(String?) onMenuChanged,
    bool isMorning,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: menuVal,
              isExpanded: true,
              hint: const Text("Menu", style: TextStyle(fontSize: 12)),
              items: menuOptions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e.toUpperCase(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onMenuChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: lockTime,
            );
            if (picked != null) {
              setState(
                () => isMorning ? morningLock = picked : nightLock = picked,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  lockTime.format(context),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        final id = meal['_id'];
        final bool isBeingEdited = mealId == id;

        final mLock = _formatLockTime(meal['morning']['lockTime']);
        final nLock = _formatLockTime(meal['night']['lockTime']);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isBeingEdited
              ? themeColor.withOpacity(0.1)
              : Colors.white, // ✅ Highlight Background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: isBeingEdited
                ? BorderSide(color: themeColor, width: 2)
                : BorderSide.none, // ✅ Highlight Border
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      meal['date'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        isBeingEdited ? Icons.edit : Icons.edit_outlined,
                        color: Colors.blue,
                      ),
                      onPressed: () => _loadMealForEdit(meal),
                    ),
                  ],
                ),
                const Divider(),
                _buildCancelTile(
                  "Morning",
                  meal['morning']['manu'],
                  mLock,
                  meal['morning']['isCancelled'] ?? false,
                  () => _handleToggleCancel(
                    id,
                    "morning",
                    meal['morning']['isCancelled'] ?? false,
                  ),
                ),
                _buildCancelTile(
                  "Night",
                  meal['night']['manu'],
                  nLock,
                  meal['night']['isCancelled'] ?? false,
                  () => _handleToggleCancel(
                    id,
                    "night",
                    meal['night']['isCancelled'] ?? false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLockTime(String isoString) {
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(isoString));
    } catch (e) {
      return "N/A";
    }
  }

  Widget _buildCancelTile(
    String label,
    String menu,
    String lockTime,
    bool isCancelled,
    VoidCallback onToggle,
  ) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        label == "Morning" ? Icons.wb_sunny : Icons.nightlight_round,
        color: isCancelled ? Colors.grey : Colors.orange,
        size: 18,
      ),
      title: Text(
        "${label.toUpperCase()}: ${menu.toUpperCase()}",
        style: TextStyle(
          decoration: isCancelled ? TextDecoration.lineThrough : null,
          color: isCancelled ? Colors.red : Colors.black87,
          fontWeight: isCancelled ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        "Locks at $lockTime",
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ), // ✅ Visible Lock Time
      trailing: TextButton(
        onPressed: onToggle,
        child: Text(
          isCancelled ? "Undo Cancel" : "Cancel",
          style: TextStyle(
            color: isCancelled ? Colors.blue : Colors.red,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return InkWell(
      onTap: mealId != null ? null : _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: themeColor),
            const SizedBox(width: 10),
            Text(
              DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (isRoutineLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (mealId == null)
              const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool isEdit = mealId != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEdit ? Colors.orange : themeColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: isLoading || isRoutineLoading ? null : _submitForm,
        child: Text(
          isEdit ? "UPDATE MEAL PLAN" : "CREATE MEAL PLAN",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(now) ? now : selectedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      await _fetchAndSetRoutine();
    }
  }
}
