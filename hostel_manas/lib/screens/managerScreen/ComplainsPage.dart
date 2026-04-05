import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:intl/intl.dart';

class ComplainsPage extends StatefulWidget {
  const ComplainsPage({super.key});

  @override
  State<ComplainsPage> createState() => _ComplainsPageState();
}

class _ComplainsPageState extends State<ComplainsPage> {
  final api = ApiService();
  List<dynamic> allComplains = [];
  bool isLoading = true;
  String selectedFilter = 'All'; // 'All', 'Pending', 'Resolved', 'Rejected'

  @override
  void initState() {
    super.initState();
    _fetchComplains();
  }

  Future<void> _fetchComplains() async {
    setState(() => isLoading = true);
    try {
      final data = await api.getComplains();
      if (mounted) {
        setState(() {
          allComplains = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching complains: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✨ FIXED: Now updates instantly without flashing the screen
  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      final result = await api.updateComplainStatus(id, newStatus);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Complain marked as $newStatus"), 
            backgroundColor: newStatus == 'Resolved' ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Update UI locally immediately instead of reloading the whole list from the server
        setState(() {
          final index = allComplains.indexWhere((c) => c['_id'] == id);
          if (index != -1) {
            allComplains[index]['status'] = newStatus;
          }
        });
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update status"), backgroundColor: Colors.red),
      );
    }
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => 
                  Container(color: Colors.white, padding: const EdgeInsets.all(20), child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredComplains = allComplains.where((c) {
      if (selectedFilter == 'All') return true;
      return c['status'].toString().toLowerCase() == selectedFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Student Complains", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Row (Added scroll view in case filters get too wide on small phones)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  _filterChip('All'),
                  const SizedBox(width: 8),
                  _filterChip('Pending'),
                  const SizedBox(width: 8),
                  _filterChip('Resolved'),
                  const SizedBox(width: 8),
                  _filterChip('Rejected'), // ✨ Added Rejected Filter
                ],
              ),
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : filteredComplains.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text("No $selectedFilter Complains", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchComplains,
                        color: Colors.deepPurple,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredComplains.length,
                          itemBuilder: (context, index) {
                            final complain = filteredComplains[index];
                            return _buildComplainCard(complain);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    bool isSelected = selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => selectedFilter = label);
      },
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildComplainCard(Map<String, dynamic> complain) {
    // Safely cast studentId in case backend population fails
    final student = complain['studentId'] is Map ? complain['studentId'] : {}; 
    final status = complain['status'].toString();
    final isPending = status.toLowerCase() == 'pending';
    
    // Status color logic
    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'resolved') statusColor = Colors.green;
    if (status.toLowerCase() == 'rejected') statusColor = Colors.red;

    String formattedDate = "Unknown Date";
    try {
      DateTime dt = DateTime.parse(complain['createdAt']);
      formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(dt.toLocal());
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade50,
                  child: const Icon(Icons.person, color: Colors.deepPurple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? "Unknown Student",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "${student['department'] ?? 'N/A'} • Reg: ${student['regNum'] ?? 'N/A'}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            
            Row(
              children: [
                const Icon(Icons.category, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  complain['category'] ?? "General",
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              complain['description'] ?? "No description provided.",
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 12),

            if (complain['imageUrl'] != null && complain['imageUrl'].toString().isNotEmpty)
              GestureDetector(
                onTap: () => _showImageDialog(complain['imageUrl']),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                    image: DecorationImage(
                      image: NetworkImage(complain['imageUrl']),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),

            // ✨ FIXED: Action Buttons (Resolve OR Reject)
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus(complain['_id'], 'Rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(complain['_id'], 'Resolved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("RESOLVE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}