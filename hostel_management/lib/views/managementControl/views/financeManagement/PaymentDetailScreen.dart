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
  
  // Keep track of local states so UI updates immediately without refetching
  late String currentStatus; 
  String? processingManagerName;
  late String _selectedMethod; // 'Offline' or 'Online'

  @override
  void initState() {
    super.initState();
    currentStatus = widget.payment['status'] ?? 'pending';
    _selectedMethod = widget.payment['paymentMethod'] ?? 'Offline';
    
    // 🛡️ CRASH FIX: Check if managerId is a populated Map before accessing ['name']
    final manager = widget.payment['managerId'];
    if (manager != null && manager is Map) {
      processingManagerName = manager['name']?.toString();
    } else {
      processingManagerName = null; // Fallback gracefully if it is a String ID or Null
    }
  }

  // Generic status updater (Approve or Reject)
  Future<void> _updateStatus(String newStatus) async {
    setState(() => isUpdating = true);
    
    // Pass status alongside the chosen payment method for approvals
    final success = await api.updateBillStatus(
      widget.payment['_id'], 
      newStatus,
      paymentMethod: newStatus == 'success' ? _selectedMethod : null,
    );
    
    setState(() => isUpdating = false);

    if (success) {
      setState(() {
        currentStatus = newStatus;
        processingManagerName = "You (Active Manager)"; 
      }); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'success' 
                ? "Payment Approved via $_selectedMethod!" 
                : "Payment Marked as Rejected!"),
            backgroundColor: newStatus == 'success' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update status"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
                tag: 'payment_screenshot_${widget.payment['_id']}',
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
      case 'rejected': case 'reject': color = Colors.red; break;
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

  Widget _buildMethodChip(String method, IconData icon) {
    final bool isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.redAccent.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.redAccent : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.redAccent : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(
                method,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.redAccent : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.payment['studentId'];
    final screenshot = widget.payment['paymentScreenshot'];
    
    // 🛡️ CRASH FIX: Safety checks if studentId is a Map or unpopulated String ID
    final bool hasStudentMap = student != null && student is Map;
    final String studentName = hasStudentMap ? (student['name'] ?? 'Unknown Student').toString() : 'Student ID: $student';
    final String studentEmail = hasStudentMap ? (student['email'] ?? 'No email linked').toString() : 'Unpopulated Student Profile';
    final String photoUrl = hasStudentMap ? (student['photoURL'] ?? "").toString() : "";
    
    final bool isApproved = currentStatus == 'success' || currentStatus == 'approved';
    final bool isRejected = currentStatus == 'rejected' || currentStatus == 'reject';

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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.redAccent.shade100,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty 
                    ? (studentName.isNotEmpty
                        ? Text(studentName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) 
                        : const Icon(Icons.person, color: Colors.white))
                    : null, 
              ),
              title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(studentEmail),
              trailing: _buildStatusBadge(),
            ),
            const Divider(),
            const SizedBox(height: 10),
            
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
                          tag: 'payment_screenshot_${widget.payment['_id']}',
                          child: Image.network(screenshot, fit: BoxFit.contain),
                        )
                      : const Center(child: Text("No screenshot uploaded", style: TextStyle(color: Colors.white))),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // PAYMENT METHOD SELECTOR (Visible during Pending workflow)
            if (!isApproved && !isRejected) ...[
              const Text("CHOOSE PAYMENT CHANNEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMethodChip("Offline", Icons.payments_outlined),
                  const SizedBox(width: 12),
                  _buildMethodChip("Online", Icons.account_balance_wallet_outlined),
                ],
              ),
              const SizedBox(height: 30),
            ] else if (isApproved) ...[
              // Display settled payment method configuration
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_score_rounded, color: Colors.indigo, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Settlement Method: ${_selectedMethod.toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            
            // Auditing Information Header Block
            if (processingManagerName != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isApproved ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isApproved ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isApproved ? Icons.verified_user_rounded : Icons.gpp_bad_rounded, 
                      color: isApproved ? Colors.green : Colors.red, 
                      size: 18
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Processed By Manager: $processingManagerName",
                        style: TextStyle(
                          fontWeight: FontWeight.w600, 
                          fontSize: 13, 
                          color: isApproved ? Colors.green.shade800 : Colors.red.shade800
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Dynamic Form Correction Action Buttons Configuration
            if (!isApproved && !isRejected) ...[
              // Standard Workflow Flow: State is currently Pending/Processing
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
                    : Text("APPROVE AS ${_selectedMethod.toUpperCase()}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            ] else if (isApproved) ...[
              // Special Corrective Flow: Already Approved, but manager can still Reject!
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
                  icon: isUpdating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)) 
                    : const Icon(Icons.undo_rounded),
                  label: const Text("REVERSE & REJECT PAYMENT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              // State fallback profile layout: Already Rejected
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: const Text(
                  "This payment request has been finalized as REJECTED.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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