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
  final api = ApiService();

  String selectedTime = "Morning";
  bool isInitialLoading = true;
  bool isActionLoading = false;
  Map<String, bool> userVotes = {"morning": false, "night": false};
  
  // Custom choice selector tracker
  String selectedPreference = "regular"; 
  
  // ✨ NEW: Track what choice string is currently saved in the database
  Map<String, String> activeSavedChoices = {"morning": "", "night": ""};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchCurrentStatus();
    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  Future<void> _fetchCurrentStatus() async {
    try {
      final response = await api.checkVoteStatus(widget.id);
      if (response['success'] == true && mounted) {
        setState(() {
          userVotes["morning"] = response['status']['morning'] ?? false;
          userVotes["night"] = response['status']['night'] ?? false;
          
          // ✨ NEW: Hydrate choice strings explicitly from API response
          activeSavedChoices["morning"] = response['status']['morningChoice'] ?? "";
          activeSavedChoices["night"] = response['status']['nightChoice'] ?? "";
          
          if (selectedTime == "Morning" && response['status']['morningChoice'] != null) {
             _syncSavedPreference(response['status']['morningChoice']);
          } else if (selectedTime == "Night" && response['status']['nightChoice'] != null) {
             _syncSavedPreference(response['status']['nightChoice']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Failed to load vote status", Colors.red);
      }
    }
  }

  void _syncSavedPreference(String savedChoice) {
    final choice = savedChoice.toLowerCase();
    if (choice == "halal_chicken") selectedPreference = "halal_chicken";
    else if (choice == "egg") selectedPreference = "egg_substitute";
    else if (choice == "veg" && (selectedTime == "Morning" ? widget.morning['manu'] : widget.night['manu']) != "veg") {
      selectedPreference = "veg_forced";
    } else {
      selectedPreference = "regular";
    }
  }

  IconData _getMealIcon(String mealType) {
    final type = mealType.toLowerCase();
    if (type.contains("chicken")) return Icons.kebab_dining_rounded;
    if (type.contains("egg")) return Icons.egg_rounded;
    if (type.contains("fish")) return Icons.set_meal_rounded;
    if (type.contains("mutton")) return Icons.dinner_dining_rounded;
    if (type.contains("paneer")) return Icons.bakery_dining_rounded;
    return Icons.grass_rounded; 
  }

  Color _getMealColor(String mealType) {
    final type = mealType.toLowerCase();
    if (type.contains("chicken") || type.contains("mutton")) return Colors.red.shade700;
    if (type.contains("egg")) return Colors.amber.shade800;
    if (type.contains("fish")) return Colors.blue.shade700;
    return Colors.green.shade700; 
  }

  // ✨ NEW: Helper text parser for clean display layout labels
  String _getPreferenceLabel(String prefCode, String baseMenu) {
    final code = prefCode.toLowerCase();
    if (code == "halal_chicken") return "HALAL CHICKEN PLATE";
    if (code == "egg" || code == "egg_substitute") return "EGG SUBSTITUTE";
    if (code == "veg" && baseMenu.toLowerCase() != "veg") return "VEGETARIAN ALTERNATIVE";
    return "REGULAR BASE OPTION (${baseMenu.toUpperCase()})";
  }

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    final currentMeal = selectedTime == "Morning" ? widget.morning : widget.night;
    final states = _calculateMealStates(currentMeal);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Meal Voting", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDateHeader(),
            const SizedBox(height: 25),
            _buildTimeSelector(),
            const SizedBox(height: 30),
            _buildMealDetailsCard(currentMeal, states),
            const SizedBox(height: 40),
            _buildActionButton(states, currentMeal),
          ],
        ),
      ),
    );
  }

  ({
    bool isCancelled,
    bool isLocked,
    bool hasVoted,
    DateTime lockDateTime,
    String formattedDeadline,
    String timeRemaining,
  }) _calculateMealStates(Map<String, dynamic> currentMeal) {
    final isCancelled = currentMeal['isCancelled'] == true;
    final lockTimeStr = currentMeal['lockTime']?.toString() ?? '';
    final lockDateTime = _parseLockTimeCorrectly(lockTimeStr);
    
    final isTimeExpired = DateTime.now().isAfter(lockDateTime);
    final isLocked = (currentMeal['isLocked'] == true) || isTimeExpired;
    final hasVoted = userVotes[selectedTime.toLowerCase()] ?? false;
    
    final formattedDeadline = DateFormat('hh:mm a, dd MMM').format(lockDateTime);
    final timeRemaining = _getTimeRemaining(lockDateTime);

    return (
      isCancelled: isCancelled,
      isLocked: isLocked,
      hasVoted: hasVoted,
      lockDateTime: lockDateTime,
      formattedDeadline: formattedDeadline,
      timeRemaining: timeRemaining,
    );
  }

  DateTime _parseLockTimeCorrectly(String lockTimeIso) {
    try {
      final mealDate = DateFormat('dd/MM/yyyy').parse(widget.date);
      final lockDT = DateTime.parse(lockTimeIso);
      return DateTime(mealDate.year, mealDate.month, mealDate.day, lockDT.hour, lockDT.minute);
    } catch (e) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, 12, 0);
    }
  }

  Widget _buildDateHeader() {
    return Column(
      children: [
        const Icon(Icons.restaurant_menu, color: Colors.deepPurple, size: 40),
        const SizedBox(height: 8),
        Text(
          "Menu for ${widget.date}",
          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Meal Time", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTimeCard(Icons.wb_sunny_outlined, "Morning", Colors.orange),
            const SizedBox(width: 12),
            _buildTimeCard(Icons.nightlight_round_outlined, "Night", Colors.indigo),
          ],
        ),
      ],
    );
  }

  Widget _buildMealDetailsCard(
    Map<String, dynamic> currentMeal, 
    ({
      bool isCancelled,
      bool isLocked,
      bool hasVoted,
      DateTime lockDateTime,
      String formattedDeadline,
      String timeRemaining,
    }) states
  ) {
    final String baseMenu = (currentMeal['manu'] ?? 'veg').toString().toLowerCase();
    final String slotKey = selectedTime.toLowerCase();
    final String savedChoice = activeSavedChoices[slotKey] ?? "";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: states.isCancelled
            ? Colors.red.withOpacity(0.05)
            : (states.isLocked ? Colors.grey[50] : Colors.deepPurple.withOpacity(0.03)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: states.isCancelled
              ? Colors.red.shade200
              : (states.hasVoted ? Colors.green : (states.isLocked ? Colors.grey[300]! : Colors.deepPurple.withOpacity(0.1))),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✨ UPDATED: Combined Voted notification banner display with clear meal layout names
          if (states.hasVoted && !states.isCancelled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 22),
                      SizedBox(width: 8),
                      Text("VOTE SUBMITTED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getMealIcon(savedChoice), color: _getMealColor(savedChoice), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _getPreferenceLabel(savedChoice, baseMenu),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Base Menu Item", style: TextStyle(color: Colors.grey, fontSize: 15)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getMealIcon(baseMenu), color: _getMealColor(baseMenu), size: 20),
                  const SizedBox(width: 6),
                  Text(baseMenu.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              )
            ],
          ),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
          _infoRow("Serial Number", "#${currentMeal['mealsNum'] ?? 'N/A'}"),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Voting Deadline", style: TextStyle(color: Colors.grey, fontSize: 15)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    states.formattedDeadline,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: states.isLocked ? Colors.red : Colors.black),
                  ),
                  if (!states.isLocked && !states.isCancelled)
                    Text("Ends in ${states.timeRemaining}", style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),

          if (!states.isLocked && !states.isCancelled && !states.hasVoted) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            const Text("Dietary Choice Preference", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            
            _buildPreferenceRadioOption("regular", "Regular Option (${baseMenu.toUpperCase()})", _getMealIcon(baseMenu), _getMealColor(baseMenu)),
            
            if (baseMenu == "chicken") ...[
              _buildPreferenceRadioOption("halal_chicken", "Halal Chicken Plate Variation", Icons.workspace_premium_rounded, Colors.red.shade800),
              _buildPreferenceRadioOption("egg_substitute", "Substitute with Egg Meals", Icons.egg_rounded, Colors.amber.shade800),
              _buildPreferenceRadioOption("veg_forced", "Force Fallback Pure Veg Option", Icons.grass_rounded, Colors.green.shade700),
            ] else if (baseMenu == "fish" || baseMenu == "mutton" || baseMenu == "paneer") ...[
              _buildPreferenceRadioOption("egg_substitute", "Substitute with Egg Meals", Icons.egg_rounded, Colors.amber.shade800),
              _buildPreferenceRadioOption("veg_forced", "Force Fallback Pure Veg Option", Icons.grass_rounded, Colors.green.shade700),
            ],
          ],

          if (states.isCancelled) ...[
            const SizedBox(height: 20),
            const Center(child: Text("THIS MEAL HAS BEEN CANCELLED", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
          ] else if (states.isLocked) ...[
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_clock, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text("VOTING CLOSED", style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceRadioOption(String value, String label, IconData optionIcon, Color iconColor) {
    return RadioListTile<String>(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(optionIcon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
      value: value,
      groupValue: selectedPreference,
      activeColor: Colors.deepPurple,
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: (val) {
        if (val != null) setState(() => selectedPreference = val);
      },
    );
  }

  String _getTimeRemaining(DateTime lockTime) {
    final difference = lockTime.difference(DateTime.now());
    if (difference.isNegative) return "Closed";
    if (difference.inDays > 0) return "${difference.inDays}d";
    if (difference.inHours > 0) return "${difference.inHours}h ${difference.inMinutes}m";
    if (difference.inMinutes > 0) return "${difference.inMinutes}m";
    return "few secs";
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildTimeCard(IconData icon, String label, Color iconColor) {
    final isSelected = selectedTime == label;
    return Expanded(
      child: GestureDetector(
        onTap: isActionLoading ? null : () {
          setState(() {
            selectedTime = label;
            selectedPreference = "regular"; 
          });
          _fetchCurrentStatus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple : Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? Colors.deepPurple : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : iconColor, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    ({
      bool isCancelled,
      bool isLocked,
      bool hasVoted,
      DateTime lockDateTime,
      String formattedDeadline,
      String timeRemaining,
    }) states, 
    Map<String, dynamic> currentMeal
  ) {
    if (states.isCancelled) return _largeButton("MEAL CANCELLED", Colors.red.shade400, null);
    if (states.isLocked) return _largeButton("VOTING CLOSED", Colors.grey[500]!, null);
    if (states.hasVoted) return _largeButton("CANCEL VOTE", Colors.redAccent, _handleCancelVote);

    return _largeButton("SUBMIT VOTE", Colors.deepPurple, () => _submitVote(currentMeal));
  }

  Widget _largeButton(String label, Color color, VoidCallback? action) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 3,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: isActionLoading || action == null ? null : action,
        child: isActionLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text("PROCESSING...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
    );
  }

  Future<void> _submitVote(Map<String, dynamic> currentMeal) async {
    final slot = selectedTime.toLowerCase();
    final originalVoteState = userVotes[slot]!;
    
    setState(() {
      userVotes[slot] = true;
      isActionLoading = true;
    });

    try {
      final response = await api.postVote({
        "mealId": widget.id,
        "timeSlot": slot,
        "mealType": selectedPreference, 
      });

      if (response['success'] == true && mounted) {
        _showSnackBar("Vote recorded successfully!", Colors.green);
        _fetchCurrentStatus(); // Recalls backend to seamlessly unpack chosen status maps strings
      } else {
        throw Exception(response['message'] ?? "Vote failed");
      }
    } catch (e) {
      setState(() => userVotes[slot] = originalVoteState);
      _showSnackBar("❌ ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => isActionLoading = false);
    }
  }

  Future<void> _handleCancelVote() async {
    final slot = selectedTime.toLowerCase();
    final originalVoteState = userVotes[slot]!;
    
    setState(() {
      userVotes[slot] = false;
      isActionLoading = true;
    });

    try {
      final response = await api.cancelVote(widget.id, slot);
      
      if (response['success'] == true && mounted) {
        _showSnackBar("Vote cancelled!", Colors.orange);
        setState(() => selectedPreference = "regular");
        _fetchCurrentStatus();
      } else {
        throw Exception(response['message'] ?? "Cancel failed");
      }
    } catch (e) {
      setState(() => userVotes[slot] = originalVoteState);
      _showSnackBar("❌ ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => isActionLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}