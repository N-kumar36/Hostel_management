import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class WeeklyRoutineModal extends StatefulWidget {
  const WeeklyRoutineModal({super.key});

  @override
  State<WeeklyRoutineModal> createState() => _WeeklyRoutineModalState();
}

class _WeeklyRoutineModalState extends State<WeeklyRoutineModal> {
  final api = ApiService();
  Map<String, dynamic>? routineData;
  bool isLoading = true;

  // Map numbers to Day names
  final Map<String, String> dayNames = {
    "1": "Monday",
    "2": "Tuesday",
    "3": "Wednesday",
    "4": "Thursday",
    "5": "Friday",
    "6": "Saturday",
    "7": "Sunday",
  };

  @override
  void initState() {
    super.initState();
    _getRoutine();
  }

  Future<void> _getRoutine() async {
    try {
      // Assuming your ApiService has this method
      final res = await api.getroutine(); 
      if (res['success'] == true) {
        setState(() {
          routineData = res['weeklyRoutine']['routine'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Routine Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300], 
              borderRadius: BorderRadius.circular(10)
            ),
          ),
          const Text(
            "Weekly Mess Routine", 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (routineData == null)
            const Center(child: Text("Failed to load routine"))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: 7,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  String dayKey = (index + 1).toString();
                  var dayRoutine = routineData![dayKey];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 85, 
                          child: Text(
                            dayNames[dayKey]!, 
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Colors.deepPurple
                            )
                          )
                        ),
                        Expanded(
                          child: Text(
                            "☀️ ${dayRoutine['morning'].toString().toUpperCase()}", 
                            style: const TextStyle(fontSize: 13)
                          )
                        ),
                        Expanded(
                          child: Text(
                            "🌙 ${dayRoutine['night'].toString().toUpperCase()}", 
                            style: const TextStyle(fontSize: 13)
                          )
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}