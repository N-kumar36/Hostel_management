import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:HostelMess/services/localServices.dart';

class StudentIdCardPage extends StatefulWidget {
  const StudentIdCardPage({super.key});

  @override
  State<StudentIdCardPage> createState() => _StudentIdCardPageState();
}

class _StudentIdCardPageState extends State<StudentIdCardPage> {
  final LocalService _localService = LocalService();

  Map<String, dynamic>? _student;
  bool _loading = true;
  String _bloodGroup = '';
  String _studentId = '';

  static const Color primary = Color(0xFF5146E5);
  static const Color background = Color(0xFFF5F6FC);

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  String _value(List<String> keys, {String fallback = 'Not available'}) {
    for (final key in keys) {
      final value = _student?[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  Future<void> _loadStudent() async {
    try {
      final data = await _localService.fetchProfile();

      if (data == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final Map<String, dynamic> student = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'])
          : Map<String, dynamic>.from(data);

      // This ID must match the studentId/userId used by Serve Meals.
      final dynamic rawId =
          student['studentId'] ??
          student['userId'] ??
          student['_id'] ??
          student['id'];

      final String id = rawId is Map
          ? (rawId['_id'] ?? rawId['id'] ?? rawId['userId'] ?? '').toString()
          : (rawId?.toString() ?? '');

      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'student_blood_group_${id.isNotEmpty ? id : "local"}';
      final savedBloodGroup = prefs.getString(storageKey) ?? '';

      if (!mounted) return;

      setState(() {
        _student = student;
        _studentId = id;
        _bloodGroup = savedBloodGroup;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Student ID card error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseBloodGroup() async {
    String selected = _bloodGroup;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select blood group',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _bloodGroups.map((group) {
                    final active = selected == group;
                    return ChoiceChip(
                      label: Text(group),
                      selected: active,
                      onSelected: (_) {
                        selected = group;
                        Navigator.pop(context, group);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('Clear blood group'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final storageKey =
        'student_blood_group_${_studentId.isNotEmpty ? _studentId : "local"}';

    if (result.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, result);
    }

    if (mounted) setState(() => _bloodGroup = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student I-Card')),
        body: const Center(
          child: Text('Unable to load student profile. Please try again.'),
        ),
      );
    }

    final name = _value(['name', 'fullName', 'studentName']);
    final regNo = _value(['regNum', 'registrationNumber', 'registrationNo']);
    final academicYear = _value(['academicYear', 'year', 'session']);
    final hostel = _value(['hostelName', 'hostel']);
    final room = _value(['roomNumber', 'roomNo', 'room']);
    final phone = _value(['phone', 'phoneNumber', 'mobile']);
    final photo = _value([
      'photoURL',
      'photoUrl',
      'profilePhoto',
    ], fallback: '');

    // Keep this QR value consistent with ServeMealPage._getStudentId().
    final qrValue = _studentId.isNotEmpty ? _studentId : regNo;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Student I-Card'),
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: const Color(0xFF181B2E),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.09),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Card header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF5146E5), Color(0xFF7968F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'HOSTELMESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hostel == 'Not available'
                              ? 'STUDENT IDENTITY CARD'
                              : hostel.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Student photo
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primary, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFFEEEEFF),
                            backgroundImage: photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 55,
                                    color: primary,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF181B2E),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEFF),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'REG. NO.  $regNo',
                            style: const TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Details grid
                        Row(
                          children: [
                            Expanded(
                              child: _detail(
                                Icons.school_outlined,
                                'ACADEMIC YEAR',
                                academicYear,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _detail(
                                Icons.meeting_room_outlined,
                                'ROOM NUMBER',
                                room,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _detail(
                                Icons.apartment_rounded,
                                'HOSTEL',
                                hostel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _chooseBloodGroup,
                                borderRadius: BorderRadius.circular(16),
                                child: _detail(
                                  Icons.bloodtype_outlined,
                                  'BLOOD GROUP',
                                  _bloodGroup.isEmpty
                                      ? 'Set blood group'
                                      : _bloodGroup,
                                  highlight: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _detail(
                          Icons.phone_outlined,
                          'PHONE NUMBER',
                          phone,
                          fullWidth: true,
                        ),

                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: const Color(0xFFE9EAF2),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'STUDENT ID QR CODE',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF181B2E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Show this code to authorized mess staff',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF74788B),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (qrValue.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE7E7EF),
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: qrValue,
                              version: QrVersions.auto,
                              size: 172,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          )
                        else
                          const Text(
                            'Student ID unavailable. Please contact the manager.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),

                        const SizedBox(height: 10),
                        Text(
                          'ID: $qrValue',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF74788B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Color(0xFF18A957),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Keep your student ID secure',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF74788B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your blood group is saved only on this device. '
                      'It is not sent to the HostelMess backend. '
                      'Check your blood group with a reliable medical record '
                      'before entering it.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF39365C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseBloodGroup,
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                _bloodGroup.isEmpty ? 'Set blood group' : 'Change blood group',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(
    IconData icon,
    String label,
    String value, {
    bool fullWidth = false,
    bool highlight = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF0EEFF) : const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: highlight ? const Color(0xFFD9D4FF) : const Color(0xFFEDEDF4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF74788B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF181B2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
