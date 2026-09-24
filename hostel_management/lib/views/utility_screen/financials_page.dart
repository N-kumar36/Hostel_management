import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // ============================================================
  // THEME HELPERS
  // ============================================================

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _divider => Theme.of(context).dividerColor;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _borderColor =>
      _isDark ? const Color(0xFF2C303A) : const Color(0xFFE5E7EB);

  Color get _inputSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF8F9FC);

  Color get _disabledSurface =>
      _isDark ? const Color(0xFF292D35) : const Color(0xFFE5E7EB);

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          "My Financials",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: FutureBuilder<List<dynamic>>(
        future: _finesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _primary));
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: TextStyle(color: _textPrimary),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refreshFines(),
              color: _primary,
              child: Stack(
                children: [
                  ListView(),
                  Center(
                    child: Text(
                      "No pending bills or fines found.",
                      style: TextStyle(color: _textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }

          final fines = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _refreshFines(),
            color: _primary,
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

  // ============================================================
  // FEE CARD
  // ============================================================

  Widget _buildFeeCard(dynamic fee) {
    final amount = fee['amount'].toString();

    // Normalize potential status variations
    final rawStatus = fee['status']?.toString().toLowerCase() ?? 'pending';

    final isPending = rawStatus == 'pending';
    final isProcessing = rawStatus == 'processing';
    final isRejected = rawStatus == 'rejected' || rawStatus == 'reject';
    final isSuccess = rawStatus == 'success' || rawStatus == 'approved';

    Color statusColor;

    if (isPending) {
      statusColor = Colors.orange;
    } else if (isProcessing) {
      statusColor = Colors.blue;
    } else if (isRejected) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.green;
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
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ==================================================
            // TITLE / DATE / AMOUNT
            // ==================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fee['title'] ?? "Mess Bill",
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        formattedDate,
                        style: TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Text(
                  "₹$amount",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: _primary,
                  ),
                ),
              ],
            ),

            Divider(height: 32, color: _divider),

            // ==================================================
            // STATUS / ACTION
            // ==================================================
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
                    isRejected ? "REJECTED" : rawStatus.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),

                // PAY NOW / TRY AGAIN
                if (isPending || isRejected)
                  ElevatedButton(
                    onPressed: () => _showPaymentSheet(fee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRejected ? Colors.redAccent : _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isRejected ? "TRY AGAIN" : "PAY NOW"),
                  )
                // PROCESSING
                else if (isProcessing)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Verifying...",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                // SUCCESS
                else if (isSuccess)
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

  // ============================================================
  // PAYMENT SHEET
  // ============================================================

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

// ==================================================================
// PAYMENT BOTTOM SHEET
// ==================================================================

class _PaymentBottomSheet extends StatefulWidget {
  final dynamic fee;
  final VoidCallback onUploadSuccess;

  const _PaymentBottomSheet({required this.fee, required this.onUploadSuccess});

  @override
  State<_PaymentBottomSheet> createState() => _PaymentBottomSheetStateState();
}

class _PaymentBottomSheetStateState extends State<_PaymentBottomSheet> {
  File? _image;
  bool _isUploading = false;
  bool isLoadingUpi = true;

  String? managerUpi;
  String? managerName;

  final api = ApiService();

  // true = Pay via Intent
  // false = View QR Code
  bool _payDirectlyMode = true;

  // ============================================================
  // THEME HELPERS
  // ============================================================

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _divider => Theme.of(context).dividerColor;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _inputSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF7F8FC);

  Color get _borderColor =>
      _isDark ? const Color(0xFF2C303A) : const Color(0xFFE2E3E8);

  Color get _disabledSurface =>
      _isDark ? const Color(0xFF292D35) : const Color(0xFFE5E7EB);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _fetchManagerUpi();
  }

  // ============================================================
  // FETCH MANAGER UPI
  // ============================================================

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

  // ============================================================
  // BUILD UPI STRING
  // ============================================================

  String _buildUpiString() {
    if (managerUpi == null) return "";

    final String pa = managerUpi!;
    final String pn = Uri.encodeComponent(managerName ?? "Hostel Manager");
    final String am = widget.fee['amount'].toString();
    final String tn = Uri.encodeComponent(widget.fee['title'] ?? "Hostel Fee");

    return "upi://pay?pa=$pa&pn=$pn&am=$am&cu=INR&tn=$tn";
  }

  // ============================================================
  // LAUNCH UPI INTENT
  // ============================================================

  Future<void> _launchUpiIntent() async {
    final upiUrl = _buildUpiString();

    if (upiUrl.isEmpty) return;

    final Uri uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "No UPI app found to process this request.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Could not open UPI app. Please use 'Scan QR' mode.",
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  // ============================================================
  // SUBMIT PAYMENT PROOF
  // ============================================================

  Future<void> _submitProof() async {
    if (_image == null) return;

    setState(() => _isUploading = true);

    try {
      final dynamic response = await api.uploadPaymentProof(
        widget.fee['_id'],
        _image!,
      );

      bool isSuccess =
          response == true || (response is Map && response['success'] == true);

      if (isSuccess && mounted) {
        final messenger = ScaffoldMessenger.of(context);

        Navigator.pop(context);

        messenger.showSnackBar(
          const SnackBar(
            content: Text("Proof submitted! Manager will verify soon."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

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
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ============================================================
  // BUILD PAYMENT SHEET
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
          // ======================================================
          // SHEET HANDLE
          // ======================================================
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: _isDark
                  ? const Color(0xFF4A4F59)
                  : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            "Choose Payment Option",
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // ======================================================
          // LOADING UPI
          // ======================================================
          if (isLoadingUpi)
            SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator(color: _primary)),
            )
          // ======================================================
          // UPI NOT CONFIGURED
          // ======================================================
          else if (managerUpi == null || managerUpi!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                "UPI ID not configured by manager.",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          // ======================================================
          // PAYMENT OPTIONS
          // ======================================================
          else ...[
            Container(
              decoration: BoxDecoration(
                color: _inputSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  // ------------------------------------------------
                  // PAY VIA UPI APP
                  // ------------------------------------------------
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _payDirectlyMode = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _payDirectlyMode
                              ? _primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "PAY VIA UPI APP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _payDirectlyMode
                                ? Colors.white
                                : _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ------------------------------------------------
                  // SCAN QR
                  // ------------------------------------------------
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _payDirectlyMode = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_payDirectlyMode
                              ? _primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "SCAN QR CODE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_payDirectlyMode
                                ? Colors.white
                                : _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ======================================================
            // PAYMENT MODE
            // ======================================================
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),

              child: _payDirectlyMode
                  // ------------------------------------------------
                  // UPI INTENT MODE
                  // ------------------------------------------------
                  ? Column(
                      key: const ValueKey('intent_mode'),
                      children: [
                        const SizedBox(height: 10),

                        Icon(
                          Icons.touch_app_outlined,
                          size: 48,
                          color: _primary,
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "Launch installed payment apps directly",
                          style: TextStyle(color: _textSecondary, fontSize: 13),
                        ),

                        const SizedBox(height: 16),

                        ElevatedButton.icon(
                          onPressed: _launchUpiIntent,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text(
                            "OPEN PAYMENT APPS",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                      ],
                    )
                  // ------------------------------------------------
                  // QR MODE
                  // ------------------------------------------------
                  : Column(
                      key: const ValueKey('qr_mode'),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderColor),
                          ),
                          child: QrImageView(
                            data: _buildUpiString(),
                            version: QrVersions.auto,
                            size: 160,
                            backgroundColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          managerName ?? "Manager",
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        Text(
                          managerUpi!,
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ],

          // ======================================================
          // STEP 2
          // ======================================================
          Divider(height: 40, color: _divider),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Step 2: Upload Screenshot",
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ======================================================
          // IMAGE PICKER
          // ======================================================
          GestureDetector(
            onTap: _isUploading ? null : _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _inputSurface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _primary.withOpacity(0.25), width: 2),
              ),

              child: _image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _primary,
                          size: 35,
                        ),

                        const SizedBox(height: 5),

                        Text(
                          "Select Screenshot",
                          style: TextStyle(fontSize: 12, color: _textSecondary),
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

          // ======================================================
          // SUBMIT BUTTON
          // ======================================================
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: (_image == null || _isUploading || managerUpi == null)
                  ? null
                  : _submitProof,

              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _disabledSurface,
                disabledForegroundColor: _textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),

              child: _isUploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
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
