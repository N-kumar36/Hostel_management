import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class RoutineManagementPage extends StatefulWidget {
  const RoutineManagementPage({super.key});

  @override
  State<RoutineManagementPage> createState() => _RoutineManagementPageState();
}

class _RoutineManagementPageState extends State<RoutineManagementPage> {
  final api = ApiService();
  bool isLoading = true;
  Map<String, dynamic> routine = {};

  final List<String> menuOptions = ["veg", "egg", "paneer", "chicken", "fish", "mutton"];
  final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  _loadRoutine() async {
    try {
      final res = await api.getroutine();
      setState(() {
        if (res['success'] == true && res['weeklyRoutine'] != null) {
          routine = Map<String, dynamic>.from(res['weeklyRoutine']['routine']);
        } else {
          _initializeEmptyRoutine();
        }
        isLoading = false;
      });
    } catch (e) {
      _initializeEmptyRoutine();
      setState(() => isLoading = false);
    }
  }

  void _initializeEmptyRoutine() {
    routine = {};
    for (int i = 1; i <= 7; i++) {
      routine[i.toString()] = {"morning": "veg", "night": "veg"};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Weekly Routine", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
          : ListView.separated(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), // Bottom padding for button space
              itemCount: 7,
              separatorBuilder: (context, index) => const Divider(height: 32, thickness: 0.5),
              itemBuilder: (context, index) {
                String dayKey = (index + 1).toString();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days[index],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _simpleDrop("Morning", dayKey, "morning", Icons.wb_sunny_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: _simpleDrop("Night", dayKey, "night", Icons.nightlight_round_outlined)),
                      ],
                    ),
                  ],
                );
              },
            ),
      // Fixed Save Button at the Bottom
      bottomSheet: isLoading 
          ? null 
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveRoutine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "SAVE WEEKLY ROUTINE",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _simpleDrop(String label, String dayKey, String timeKey, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: routine[dayKey][timeKey],
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
              items: menuOptions.map((e) => DropdownMenuItem(
                value: e, 
                child: Text(e.toUpperCase(), style: const TextStyle(letterSpacing: 0.5))
              )).toList(),
              onChanged: (val) => setState(() => routine[dayKey][timeKey] = val),
            ),
          ),
        ),
      ],
    );
  }

  _saveRoutine() async {
    setState(() => isLoading = true);
    try {
      await api.setroutine({"routine": routine});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Routine Saved Successfully"), backgroundColor: Colors.teal),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}