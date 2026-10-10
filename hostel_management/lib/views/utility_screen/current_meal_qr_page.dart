import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:HostelMess/services/api_service.dart';

class CurrentMealQrPage extends StatefulWidget {
  const CurrentMealQrPage({super.key});

  @override
  State<CurrentMealQrPage> createState() => _CurrentMealQrPageState();
}

class _CurrentMealQrPageState extends State<CurrentMealQrPage> {
  static const Color primary = Color(0xFF5B4FE9);
  static const Color background = Color(0xFFF7F8FC);

  final ApiService api = ApiService();

  bool isLoading = true;
  String? errorMessage;
  String studentId = '';
  String studentName = '';

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final profile = await api.getProfile();

      if (profile == null) {
        throw Exception('Unable to load your profile. Please log in again.');
      }

      final id =
          (profile['_id'] ??
                  profile['id'] ??
                  profile['studentId'] ??
                  profile['userId'] ??
                  '')
              .toString()
              .trim();

      if (id.isEmpty) {
        throw Exception('Student ID was not found in your profile.');
      }

      if (!mounted) return;

      setState(() {
        studentId = id;
        studentName =
            (profile['name'] ??
                    profile['studentName'] ??
                    profile['fullName'] ??
                    profile['username'] ??
                    'Student')
                .toString();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'My Student QR',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: background,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isLoading ? null : _loadStudent,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: isLoading
                ? const CircularProgressIndicator(color: primary)
                : errorMessage != null
                ? _buildError()
                : _buildQrCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your Student QR Code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            studentName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: QrImageView(
              // QR payload contains ONLY the student ID.
              data: studentId,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'STUDENT ID',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            studentId,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: primary, size: 21),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show this QR code to the mess manager. '
                    'The QR contains only your student ID; '
                    'meal information is handled by the serving page.',
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 48,
          ),
          const SizedBox(height: 14),
          const Text(
            'Unable to Generate QR',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadStudent,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
