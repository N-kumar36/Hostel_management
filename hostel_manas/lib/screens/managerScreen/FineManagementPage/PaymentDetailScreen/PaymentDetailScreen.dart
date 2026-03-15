import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class PaymentDetailScreen extends StatefulWidget {
  final dynamic payment;
  const PaymentDetailScreen({super.key, required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  bool isVerifying = false;
  final api = ApiService();

  Future<void> _confirmPayment() async {
    setState(() => isVerifying = true);
    final success = await api.verifyPayment(widget.payment['_id']);
    setState(() => isVerifying = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment Verified!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    }
  }

  // ✅ Function to open Image in Full Screen
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
                tag: 'payment_screenshot',
                child: Image.network(imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.payment['studentId'];
    final screenshot = widget.payment['paymentScreenshot'];
    final String photoUrl = student?['photoURL'] ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Payment"), 
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
                child: photoUrl.isEmpty 
                    ? Text(student['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) 
                    : null,
              ),
              title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(student['email']),
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text("Reason: ${widget.payment['title']}", style: const TextStyle(fontSize: 16)),
            Text("Amount: ₹${widget.payment['amount']}", 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            
            const Text("PAYMENT SCREENSHOT (Tap to expand)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            
            // ✅ Screenshot Container with Click to Full Screen
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
                          tag: 'payment_screenshot',
                          child: Image.network(screenshot, fit: BoxFit.contain),
                        )
                      : const Center(child: Text("No screenshot uploaded", style: TextStyle(color: Colors.white))),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: isVerifying ? null : _confirmPayment,
                child: isVerifying 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("APPROVE & MARK AS PAID", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}