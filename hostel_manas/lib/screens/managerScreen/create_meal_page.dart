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
  String? currentMorningMealNum;
  String? currentNightMealNum;

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

  void _autoSelectNextDate() {
    if (meals.isEmpty) {
      setState(() => selectedDate = DateTime.now());
      return;
    }

    try {
      final dates = meals.map<DateTime>((m) {
        return DateFormat('dd/MM/yyyy').parse(m['date'] as String);
      }).toList()..sort((a, b) => b.compareTo(a));

      final latestDate = dates.first;
      DateTime nextDate = latestDate.add(const Duration(days: 1));

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (nextDate.isBefore(today)) {
        nextDate = today; 
      }

      setState(() {
        selectedDate = nextDate;
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
      try {
        mealId = meal['_id'];
        
        // ✨ FIXED: Extract meal numbers from inside the respective slot objects matching your schema
        currentMorningMealNum = meal['morning']?['mealsNum']?.toString();
        currentNightMealNum = meal['night']?['mealsNum']?.toString();
        
        if (meal['date'] != null) {
          selectedDate = DateFormat('dd/MM/yyyy').parse(meal['date'].toString());
        }
        
        selectedMorningMenu = meal['morning']?['manu'];
        selectedNightMenu = meal['night']?['manu'];
        
        final morningRawTime = meal['morning']?['lockTime'] ?? "";
        final nightRawTime = meal['night']?['lockTime'] ?? "";

        morningLock = morningRawTime.toString().contains("T") 
            ? TimeOfDay.fromDateTime(DateTime.parse(morningRawTime).toLocal())
            : const TimeOfDay(hour: 7, minute: 0);

        nightLock = nightRawTime.toString().contains("T") 
            ? TimeOfDay.fromDateTime(DateTime.parse(nightRawTime).toLocal())
            : const TimeOfDay(hour: 17, minute: 0);
      } catch (e) {
        debugPrint("Error loading operational targets inside form elements: $e");
      }
    });
  }

  void _resetForm() {
    setState(() {
      mealId = null;
      currentMorningMealNum = null;
      currentNightMealNum = null;
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
      if (res['success'] == true && mounted) {
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
          
      if (mounted) {
        _showSnackBar(res['message'] ?? "Success!", Colors.green);
        _resetForm();
        _fetchMeals();
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAutoGenerateDialog() {
    DateTime dialogStartDate = selectedDate;
    DateTime dialogEndDate = selectedDate.add(const Duration(days: 29));

    TimeOfDay dialogMorningLock = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay dialogNightLock = const TimeOfDay(hour: 17, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final int daysCount = dialogEndDate.difference(dialogStartDate).inDays + 1;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Auto-Generate Meals",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select the date range and default lock times to auto-generate meals.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: themeColor.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "$daysCount DAYS",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                        const Text(
                          "Total meals to generate",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Start Date", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(dialogStartDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: Icon(Icons.calendar_today, color: themeColor),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dialogStartDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          dialogStartDate = picked;
                          if (dialogEndDate.isBefore(dialogStartDate)) {
                            dialogEndDate = dialogStartDate.add(const Duration(days: 29));
                          }
                        });
                      }
                    },
                  ),
                  const Divider(height: 5),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("End Date", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(dialogEndDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: Icon(Icons.calendar_today, color: themeColor),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dialogEndDate,
                        firstDate: dialogStartDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => dialogEndDate = picked);
                      }
                    },
                  ),
                  const Divider(height: 5),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Morning Lock Time", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      dialogMorningLock.format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: Icon(Icons.access_time, color: Colors.orange.shade400),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: dialogMorningLock,
                      );
                      if (picked != null) {
                        setDialogState(() => dialogMorningLock = picked);
                      }
                    },
                  ),
                  const Divider(height: 5),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Night Lock Time", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      dialogNightLock.format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: Icon(Icons.access_time, color: Colors.indigo.shade400),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: dialogNightLock,
                      );
                      if (picked != null) {
                        setDialogState(() => dialogNightLock = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _triggerAutoGenerate(
                    dialogStartDate,
                    dialogEndDate,
                    dialogMorningLock,
                    dialogNightLock,
                  );
                },
                child: Text("GENERATE $daysCount DAYS"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _triggerAutoGenerate(
    DateTime start,
    DateTime end,
    TimeOfDay mLock,
    TimeOfDay nLock,
  ) async {
    setState(() => isLoading = true);
    try {
      final String formattedMorningLock =
          '${mLock.hour.toString().padLeft(2, '0')}:${mLock.minute.toString().padLeft(2, '0')}';
      final String formattedNightLock =
          '${nLock.hour.toString().padLeft(2, '0')}:${nLock.minute.toString().padLeft(2, '0')}';

      final payload = {
        "startDate": DateFormat('dd/MM/yyyy').format(start),
        "endDate": DateFormat('dd/MM/yyyy').format(end),
        "morningLockTime": formattedMorningLock,
        "nightLockTime": formattedNightLock,
      };

      final res = await api.autoGenerateMeals(payload);

      if (res['success'] == true && mounted) {
        _showSnackBar(res['message'] ?? "Meals generated!", Colors.green);
        _resetForm();
        _fetchMeals();
      } else if (mounted) {
        _showSnackBar(res['message'] ?? "Generation failed", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Meal Management", style: TextStyle(fontWeight: FontWeight.bold)),
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
          Expanded(
            child: isLoading && meals.isEmpty 
                ? Center(child: CircularProgressIndicator(color: themeColor)) 
                : _buildMealsList()
          ),
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
        border: mealId != null ? Border.all(color: themeColor, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
            // ✨ FIXED: Dynamic UI badge informing the manager which meal slot indexes are currently selected
            if (currentMorningMealNum != null || currentNightMealNum != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (currentMorningMealNum != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          "Morning Index: #$currentMorningMealNum",
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (currentMorningMealNum != null && currentNightMealNum != null) const SizedBox(width: 8),
                  if (currentNightMealNum != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          "Night Index: #$currentNightMealNum",
                          style: TextStyle(color: Colors.indigo.shade800, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toUpperCase(), style: const TextStyle(fontSize: 13)),
                      ))
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
              setState(() => isMorning ? morningLock = picked : nightLock = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(lockTime.format(context), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
        
        // ✨ FIXED: Pull mealsNum individually from within both sub-objects in the card view below
        final String morningNum = meal['morning']?['mealsNum']?.toString() ?? "N/A";
        final String nightNum = meal['night']?['mealsNum']?.toString() ?? "N/A";

        final mLock = _formatLockTime(meal['morning']?['lockTime'] ?? "");
        final nLock = _formatLockTime(meal['night']?['lockTime'] ?? "");

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isBeingEdited ? themeColor.withOpacity(0.1) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: isBeingEdited ? BorderSide(color: themeColor, width: 2) : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(meal['date'] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(isBeingEdited ? Icons.edit : Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _loadMealForEdit(meal),
                    ),
                  ],
                ),
                const Divider(height: 8),
                
                // Morning Tile Slot View Component
                _buildCancelTile(
                  "Morning",
                  meal['morning']?['manu'] ?? "N/A",
                  mLock,
                  morningNum, // Added dynamic sequence display
                  meal['morning']?['isCancelled'] ?? false,
                  () => _handleToggleCancel(id, "morning", meal['morning']?['isCancelled'] ?? false),
                ),
                const SizedBox(height: 4),
                
                // Night Tile Slot View Component
                _buildCancelTile(
                  "Night",
                  meal['night']?['manu'] ?? "N/A",
                  nLock,
                  nightNum, // Added dynamic sequence display
                  meal['night']?['isCancelled'] ?? false,
                  () => _handleToggleCancel(id, "night", meal['night']?['isCancelled'] ?? false),
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
      if (isoString.isEmpty) return "N/A";
      return DateFormat('hh:mm a').format(DateTime.parse(isoString).toLocal());
    } catch (e) {
      return "N/A";
    }
  }

  Widget _buildCancelTile(
    String label,
    String menu,
    String lockTime,
    String mealNumber, // ✨ Captured from nested object maps
    bool isCancelled,
    VoidCallback onToggle,
  ) {
    bool isMorning = label == "Morning";
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isMorning ? Icons.wb_sunny : Icons.nightlight_round,
        color: isCancelled ? Colors.grey : (isMorning ? Colors.orange : Colors.indigo.shade400),
        size: 18,
      ),
      title: Row(
        children: [
          Text(
            "${label.toUpperCase()}: ${menu.toUpperCase()}",
            style: TextStyle(
              decoration: isCancelled ? TextDecoration.lineThrough : null,
              color: isCancelled ? Colors.red : Colors.black87,
              fontWeight: isCancelled ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          // ✨ FIXED: Added distinct sequence indicator tags inside individual meal rows
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isCancelled ? Colors.grey.shade100 : (isMorning ? Colors.orange.shade50 : Colors.indigo.shade50),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "#$mealNumber",
              style: TextStyle(
                fontSize: 8.5, 
                fontWeight: FontWeight.bold, 
                color: isCancelled ? Colors.grey : (isMorning ? Colors.orange.shade800 : Colors.indigo.shade800)
              ),
            ),
          ),
        ],
      ),
      subtitle: Text("Locks at $lockTime", style: const TextStyle(fontSize: 10, color: Colors.grey)),
      trailing: TextButton(
        onPressed: onToggle,
        child: Text(
          isCancelled ? "Undo Cancel" : "Cancel",
          style: TextStyle(color: isCancelled ? Colors.blue : Colors.red, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return InkWell(
      onTap: mealId != null ? null : _pickDate,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else if (mealId == null)
              const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool isEdit = mealId != null;
    return Column(
      children: [
        Row(
          children: [
            if (isEdit) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Colors.amber, width: 2),
                  ),
                  onPressed: _resetForm,
                  child: const Text(
                    "CANCEL EDIT",
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEdit ? Colors.orange : themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isLoading || isRoutineLoading ? null : _submitForm,
                child: Text(
                  isEdit ? "UPDATE PLAN" : "CREATE PLAN",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        if (!isEdit) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: themeColor, width: 2),
              ),
              onPressed: isLoading || isRoutineLoading ? null : _showAutoGenerateDialog,
              icon: Icon(Icons.auto_mode, color: themeColor),
              label: Text(
                "AUTO GENERATE MULTIPLE DAYS",
                style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes")),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
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
    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
      await _fetchAndSetRoutine();
    }
  }
}