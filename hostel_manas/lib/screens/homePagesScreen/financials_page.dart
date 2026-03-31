import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:HostelMess/services/api_service.dart';

class FinancialsPage extends StatefulWidget {
  const FinancialsPage({super.key});

  @override
  State<FinancialsPage> createState() => _FinancialsPageState();
}

class _FinancialsPageState extends State<FinancialsPage> {
  final api = ApiService();
  late Future<List<dynamic>> _finesFuture;

  @override
  void initState() {
    super.initState();
    _refreshFines();
  }

  void _refreshFines() {
    setState(() {
      _finesFuture = api.getMyFines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "My Financials",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _finesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refreshFines(),
              child: Stack(
                children: [
                  ListView(),
                  const Center(child: Text("No pending bills or fines found.")),
                ],
              ),
            );
          }

          final fines = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshFines(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fines.length,
              itemBuilder: (context, index) {
                return _buildFeeCard(fines[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeeCard(dynamic fee) {
    final amount = fee['amount'].toString();
    final status = fee['status']?.toString().toLowerCase() ?? 'pending';

    // ✅ FIXED: Explicitly handle colors for all statuses
    Color statusColor;
    if (status == 'pending') {
      statusColor = Colors.orange; // Pending looks better as orange
    } else if (status == 'processing') {
      statusColor = Colors.blue; 
    } else if (status == 'rejected') {
      statusColor = Colors.red; // Rejected is explicitly red
    } else {
      statusColor = Colors.green; // Success/Approved
    }

    String formattedDate = "";
    try {
      if (fee['date'] != null) {
        formattedDate = DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.parse(fee['date']));
      }
    } catch (e) {
      formattedDate = fee['date'] ?? "";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fee['title'] ?? "Mess Bill",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  "₹$amount",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                
                // ✅ FIXED: Show button for 'pending' AND 'rejected'
                if (status == 'pending' || status == 'rejected')
                  ElevatedButton(
                    onPressed: () => _showPaymentSheet(fee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'rejected' ? Colors.redAccent : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Change text if they are trying again
                    child: Text(status == 'rejected' ? "TRY AGAIN" : "PAY NOW"),
                  )
                else if (status == 'processing')
                  const Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        "Verifying...",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (status == 'success' || status == 'approved')
                   const Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text(
                        "Paid",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(dynamic fee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _PaymentBottomSheet(fee: fee, onUploadSuccess: _refreshFines),
    );
  }
}

class _PaymentBottomSheet extends StatefulWidget {
  final dynamic fee;
  final VoidCallback onUploadSuccess;
  const _PaymentBottomSheet({required this.fee, required this.onUploadSuccess});

  @override
  State<_PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<_PaymentBottomSheet> {
  File? _image;
  bool _isUploading = false;
  bool isLoadingUpi = true;
  String? managerUpi;
  String? managerName;
  final api = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchManagerUpi();
  }

  Future<void> _fetchManagerUpi() async {
    try {
      final data = await api.getManagerUpi();
      if (data != null) {
        setState(() {
          managerUpi = data['upiId'];
          managerName = data['merchantName'];
          isLoadingUpi = false;
        });
      } else {
        setState(() => isLoadingUpi = false);
      }
    } catch (e) {
      debugPrint("UPI Fetch Error: $e");
      setState(() => isLoadingUpi = false);
    }
  }

  String _buildUpiString() {
    if (managerUpi == null) return "";
    final String pa = managerUpi!;
    final String pn = Uri.encodeComponent(managerName ?? "Hostel Manager");
    final String am = widget.fee['amount'].toString();
    final String tn = Uri.encodeComponent(widget.fee['title'] ?? "Hostel Fee");

    // NPCI standard UPI format
    return "upi://pay?pa=$pa&pn=$pn&am=$am&cu=INR&tn=$tn";
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  Future<void> _submitProof() async {
    if (_image == null) return;
    setState(() => _isUploading = true);

    try {
      // Ensure success is treated as a boolean
      final dynamic response = await api.uploadPaymentProof(widget.fee['_id'], _image!);
      
      // Check if response is true or contains a success key
      bool isSuccess = response == true || (response is Map && response['success'] == true);

      if (isSuccess && mounted) {
        // Store messenger state before popping
        final messenger = ScaffoldMessenger.of(context);

        // 1. Close the bottom sheet first
        Navigator.pop(context);

        // 2. Show the message on the main screen
        messenger.showSnackBar(
          const SnackBar(
            content: Text(" Proof submitted! Manager will verify soon."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 3. Trigger the refresh
        widget.onUploadSuccess();
      } else {
        throw Exception("Server rejected the file.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: ${e.toString()}"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        top: 25,
        left: 25,
        right: 25,
        bottom: MediaQuery.of(context).viewInsets.bottom + 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Scan to Pay",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          if (isLoadingUpi)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (managerUpi == null || managerUpi!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                "UPI ID not configured by manager.",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Column(
              children: [
                QrImageView(
                  data: _buildUpiString(),
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  managerName ?? "Manager",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  managerUpi!,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),

          const Divider(height: 40),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Step 2: Upload Screenshot",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isUploading ? null : _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.deepPurple.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.deepPurple,
                          size: 35,
                        ),
                        Text(
                          "Select Screenshot",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: (_image == null || _isUploading || managerUpi == null)
                  ? null
                  : _submitProof,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "SUBMIT FOR VERIFICATION",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}