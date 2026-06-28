import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class PaymentDetailScreen extends StatefulWidget {
  final dynamic payment;
  const PaymentDetailScreen({super.key, required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  bool isUpdating = false;
  final api = ApiService();
  
  // Keep track of local status so UI updates immediately without refetching
  late String currentStatus; 

  @override
  void initState() {
    super.initState();
    currentStatus = widget.payment['status'] ?? 'pending';
  }

  // Generic status updater (Approve or Reject)
  Future<void> _updateStatus(String newStatus) async {
    setState(() => isUpdating = true);
    
    // Call the new updateBillStatus API method we added in the previous step
    final success = await api.updateBillStatus(widget.payment['_id'], newStatus);
    
    setState(() => isUpdating = false);

    if (success) {
      setState(() => currentStatus = newStatus); // Update local UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'success' ? "Payment Approved!" : "Payment Rejected!"),
            backgroundColor: newStatus == 'success' ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context); // Go back to the list
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update status"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Function to open Image in Full Screen
  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true, 
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'payment_screenshot_${widget.payment['_id']}', // Make tag unique
                child: Image.network(imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    switch (currentStatus.toLowerCase()) {
      case 'pending': color = Colors.orange; break;
      case 'processing': color = Colors.blue; break;
      case 'success': case 'approved': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      default: color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        currentStatus.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.payment['studentId'];
    final screenshot = widget.payment['paymentScreenshot'];
    final String photoUrl = student?['photoURL'] ?? "";
    
    // Check if the bill is already finalized
    final bool isFinalized = currentStatus == 'success' || currentStatus == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Details"), 
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Fixed Student Info Header with Profile Image
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.redAccent.shade100,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                // ✅ FIXED CHILD LOGIC: Return null if image exists so it doesn't overlay the icon
                child: photoUrl.isEmpty 
                    ? (student != null && student['name'] != null && student['name'].toString().isNotEmpty
                        ? Text(student['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) 
                        : const Icon(Icons.person, color: Colors.white))
                    : null, 
              ),
              title: Text(student?['name'] ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(student?['email'] ?? 'No email provided'),
              trailing: _buildStatusBadge(), // Show current status badge
            ),
            const Divider(),
            const SizedBox(height: 10),
            
            // Bill Details
            Text("Reason: ${widget.payment['title'] ?? 'N/A'}", style: const TextStyle(fontSize: 16)),
            if (widget.payment['description'] != null && widget.payment['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text("Notes: ${widget.payment['description']}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            const SizedBox(height: 10),
            Text("Amount: ₹${widget.payment['amount'] ?? 0}", 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            
            const Text("PAYMENT SCREENSHOT (Tap to expand)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            
            // Screenshot Container with Click to Full Screen
            GestureDetector(
              onTap: () => screenshot != null && screenshot != "" ? _openFullScreenImage(screenshot) : null,
              child: Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: screenshot != null && screenshot != ""
                      ? Hero(
                          tag: 'payment_screenshot_${widget.payment['_id']}', // Make tag unique
                          child: Image.network(screenshot, fit: BoxFit.contain),
                        )
                      : const Center(child: Text("No screenshot uploaded", style: TextStyle(color: Colors.white))),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Action Buttons (Only show if not already approved/rejected)
            if (!isFinalized) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: isUpdating ? null : () => _updateStatus('success'),
                  icon: isUpdating ? const SizedBox() : const Icon(Icons.check_circle),
                  label: isUpdating 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("APPROVE & MARK AS PAID", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: isUpdating ? null : () => _updateStatus('rejected'),
                  icon: const Icon(Icons.cancel),
                  label: const Text("REJECT PAYMENT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
               Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Text(
                  "This bill has already been ${currentStatus.toUpperCase()}.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
               )
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}