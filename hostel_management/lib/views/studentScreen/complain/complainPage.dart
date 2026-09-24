import 'dart:io';

import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ComplainPage extends StatefulWidget {
  const ComplainPage({super.key});

  @override
  State<ComplainPage> createState() => _ComplainPageState();
}

class _ComplainPageState extends State<ComplainPage> {
  // ===========================================================================
  // FORM / SERVICES
  // ===========================================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ApiService api = ApiService();

  final TextEditingController _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // ===========================================================================
  // THEME-AWARE COLORS
  // ===========================================================================

  // Semantic colors intentionally remain fixed.
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFD97706);

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _primaryDark => const Color(0xFF3F35A8);

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textDark => Theme.of(context).colorScheme.onSurface;

  Color get _textGrey => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _divider => Theme.of(context).dividerColor;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _borderColor =>
      _isDark ? const Color(0xFF2C303A) : const Color(0xFFE5E7EB);

  Color get _subtleSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF8F8FC);

  Color get _softPrimary =>
      _isDark ? const Color(0xFF292650) : const Color(0xFFEEEDFF);

  // ===========================================================================
  // REQUEST TYPES
  // ===========================================================================

  String _selectedType = 'Complaint';

  final List<Map<String, dynamic>> _requestTypes = [
    {
      'title': 'Complaint',
      'subtitle': 'Report an issue',
      'icon': Icons.report_problem_rounded,
      'color': const Color(0xFFDC2626),
    },
    {
      'title': 'App Problem',
      'subtitle': 'Technical issue',
      'icon': Icons.bug_report_rounded,
      'color': const Color(0xFF7C3AED),
    },
    {
      'title': 'Suggestion',
      'subtitle': 'Help us improve',
      'icon': Icons.lightbulb_rounded,
      'color': const Color(0xFFD97706),
    },
    {
      'title': 'Meeting',
      'subtitle': 'Request discussion',
      'icon': Icons.groups_rounded,
      'color': const Color(0xFF2563EB),
    },
  ];

  // ===========================================================================
  // ENUM CATEGORIES
  // ===========================================================================

  String _selectedCategory = 'Food Quality';

  // These values MUST match the backend enum.

  final List<String> _complaintCategories = [
    'Food Quality',
    'Hygiene Issue',
    'Staff Behavior',
    'Meal Timing',
    'Mess Facilities',
    'Other',
  ];

  final List<String> _appCategories = [
    'Login / Authentication',
    'Meal Voting',
    'Profile Problem',
    'Notification Problem',
    'Photo Upload Problem',
    'App Crash / Bug',
    'Other',
  ];

  final List<String> _suggestionCategories = [
    'Food / Menu',
    'Mess Management',
    'App Improvement',
    'Hostel Facility',
    'New Feature',
    'Other',
  ];

  final List<String> _meetingCategories = [
    'Mess Committee Discussion',
    'Food / Menu Discussion',
    'Hostel Issue',
    'Personal Discussion',
    'App / Technical Discussion',
    'Suggestion Discussion',
    'Other',
  ];

  // ===========================================================================
  // MEETING
  // ===========================================================================

  DateTime? _meetingDate;
  TimeOfDay? _meetingTime;

  // ===========================================================================
  // IMAGE
  // ===========================================================================

  File? _selectedImage;

  // ===========================================================================
  // LOADING
  // ===========================================================================

  bool _isLoading = false;

  // ===========================================================================
  // CURRENT CATEGORY LIST
  // ===========================================================================

  List<String> get _currentCategories {
    switch (_selectedType) {
      case 'App Problem':
        return _appCategories;

      case 'Suggestion':
        return _suggestionCategories;

      case 'Meeting':
        return _meetingCategories;

      case 'Complaint':
      default:
        return _complaintCategories;
    }
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // CHANGE REQUEST TYPE
  // ===========================================================================

  void _changeRequestType(String type) {
    if (_isLoading) return;

    setState(() {
      _selectedType = type;

      final categories = _currentCategories;

      if (!categories.contains(_selectedCategory)) {
        _selectedCategory = categories.first;
      }

      _meetingDate = null;
      _meetingTime = null;
    });
  }

  // ===========================================================================
  // PICK IMAGE
  // ===========================================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        _selectedImage = File(image.path);
      });
    } catch (e) {
      debugPrint('Image picking error: $e');

      _showSnackBar('Unable to select image.', _danger);
    }
  }

  // ===========================================================================
  // IMAGE SOURCE OPTIONS
  // ===========================================================================

  void _showImageSourceOptions() {
    if (_isLoading) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetTheme.dividerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  'Attach Image',
                  style: TextStyle(
                    color: sheetTheme.colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Choose where you want to get the image from',
                  style: TextStyle(
                    color: sheetTheme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.camera_alt_rounded,
                        title: 'Camera',
                        subtitle: 'Take photo',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.photo_library_rounded,
                        title: 'Gallery',
                        subtitle: 'Choose photo',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // IMAGE SOURCE BUTTON
  // ===========================================================================

  Widget _buildImageSourceButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 10),
        decoration: BoxDecoration(
          color: _subtleSurface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: _softPrimary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: _primary, size: 21),
            ),

            const SizedBox(height: 9),

            Text(
              title,
              style: TextStyle(
                color: _textDark,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 2),

            Text(subtitle, style: TextStyle(color: _textGrey, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DATE PICKER
  // ===========================================================================

  Future<void> _pickMeetingDate() async {
    if (_isLoading) return;

    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: _meetingDate ?? now,
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _meetingDate = picked;
    });
  }

  // ===========================================================================
  // TIME PICKER
  // ===========================================================================

  Future<void> _pickMeetingTime() async {
    if (_isLoading) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _meetingTime = picked;
    });
  }

  // ===========================================================================
  // SUBMIT
  // ===========================================================================

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // -------------------------------------------------------------------------
    // MEETING VALIDATION
    // -------------------------------------------------------------------------

    if (_selectedType == 'Meeting') {
      if (_meetingDate == null) {
        _showSnackBar('Please select your preferred meeting date.', _warning);
        return;
      }

      if (_meetingTime == null) {
        _showSnackBar('Please select your preferred meeting time.', _warning);
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // -----------------------------------------------------------------------
      // REAL BACKEND ENUMS
      // -----------------------------------------------------------------------
      //
      // requestType:
      // Complaint
      // App Problem
      // Suggestion
      // Meeting
      //
      // category:
      // Depends on requestType.
      //
      // No more "Other" workaround.
      // -----------------------------------------------------------------------

      final String requestType = _selectedType;
      final String category = _selectedCategory;

      final String description = _descriptionController.text.trim();

      String? meetingTimeString;

      if (_selectedType == 'Meeting' && _meetingTime != null) {
        meetingTimeString = _meetingTime!.format(context);
      }

      // -----------------------------------------------------------------------
      // DEBUG
      // -----------------------------------------------------------------------

      debugPrint('==============================================');

      debugPrint('Submitting support request');

      debugPrint('Request Type: $requestType');

      debugPrint('Category: $category');

      debugPrint('Description: $description');

      debugPrint('Meeting Date: ${_meetingDate?.toIso8601String()}');

      debugPrint('Meeting Time: $meetingTimeString');

      debugPrint('==============================================');

      // -----------------------------------------------------------------------
      // API
      // -----------------------------------------------------------------------

      final res = await api.createComplaintWithImage(
        requestType: requestType,
        category: category,
        description: description,
        meetingDate: _meetingDate,
        meetingTime: meetingTimeString,
        image: _selectedImage,
      );

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // SUCCESS
      // -----------------------------------------------------------------------

      if (res['success'] == true) {
        _showSuccessDialog();
      }
      // -----------------------------------------------------------------------
      // FAILURE
      // -----------------------------------------------------------------------
      else {
        final String message =
            res['message']?.toString() ??
            'Submission failed. Please try again.';

        debugPrint('Support request failed: $message');

        _showSnackBar(message, _danger);
      }
    } catch (e, stackTrace) {
      debugPrint('Support request error: $e');

      debugPrint(stackTrace.toString());

      if (!mounted) return;

      _showSnackBar('Connection error. Please try again.', _danger);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // SUCCESS DIALOG
  // ===========================================================================

  void _showSuccessDialog() {
    String title;
    String message;
    IconData icon;

    switch (_selectedType) {
      case 'App Problem':
        title = 'Problem Reported';
        message = 'Your app-related problem has been submitted successfully.';
        icon = Icons.bug_report_rounded;
        break;

      case 'Suggestion':
        title = 'Suggestion Sent';
        message = 'Thank you for helping us improve the experience.';
        icon = Icons.lightbulb_rounded;
        break;

      case 'Meeting':
        title = 'Request Sent';
        message =
            'Your meeting request has been submitted with your preferred date and time.';
        icon = Icons.groups_rounded;
        break;

      case 'Complaint':
      default:
        title = 'Complaint Submitted';
        message = 'Your complaint has been submitted successfully.';
        icon = Icons.check_circle_rounded;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogTheme = Theme.of(dialogContext);

        return AlertDialog(
          backgroundColor: dialogTheme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 25, 24, 15),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF173527)
                      : const Color(0xFFEAF8EF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _success, size: 35),
              ),

              const SizedBox(height: 17),

              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogTheme.colorScheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogTheme.colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _background,
        foregroundColor: _textDark,
        centerTitle: false,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: TextStyle(
                color: _textDark,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'We are here to listen',
              style: TextStyle(
                color: _textGrey,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),

              const SizedBox(height: 20),

              _buildSectionTitle(
                'How can we help?',
                'Choose what you want to send',
              ),

              const SizedBox(height: 11),

              _buildRequestTypeGrid(),

              const SizedBox(height: 23),

              _buildSectionTitle(_getFormTitle(), _getSectionSubtitle()),

              const SizedBox(height: 11),

              _buildCategoryField(),

              const SizedBox(height: 16),

              if (_selectedType == 'Meeting') ...[
                _buildMeetingSchedule(),
                const SizedBox(height: 16),
              ],

              _buildDescriptionField(),

              const SizedBox(height: 17),

              _buildAttachmentSection(),

              const SizedBox(height: 25),

              _buildSubmitButton(),

              const SizedBox(height: 10),

              Center(child: _buildPrivacyNote()),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO CARD
  // ===========================================================================

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryDark],
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tell us what happened, share an idea, or request a discussion.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: _textGrey, fontSize: 9)),
      ],
    );
  }

  // ===========================================================================
  // REQUEST TYPE GRID
  // ===========================================================================

  Widget _buildRequestTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _requestTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.85,
      ),
      itemBuilder: (context, index) {
        final item = _requestTypes[index];

        final String title = item['title'];

        final bool selected = _selectedType == title;

        final Color color = item['color'];

        return InkWell(
          onTap: () => _changeRequestType(title),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.08) : _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : _borderColor,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: [
                if (!selected)
                  BoxShadow(
                    color: _isDark
                        ? Colors.black.withOpacity(0.18)
                        : Colors.black.withOpacity(0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item['icon'], color: color, size: 19),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        item['subtitle'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textGrey, fontSize: 7.5),
                      ),
                    ],
                  ),
                ),

                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 17),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // CATEGORY FIELD
  // ===========================================================================

  Widget _buildCategoryField() {
    return _buildFieldContainer(
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: TextStyle(
            color: _textGrey,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.category_outlined, color: _primary, size: 19),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 4,
          ),
        ),
        dropdownColor: _surface,
        borderRadius: BorderRadius.circular(14),
        items: _currentCategories
            .map(
              (category) => DropdownMenuItem<String>(
                value: category,
                child: Text(
                  category,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: _isLoading
            ? null
            : (value) {
                if (value == null) return;

                setState(() {
                  _selectedCategory = value;
                });
              },
      ),
    );
  }

  // ===========================================================================
  // MEETING SCHEDULE
  // ===========================================================================

  Widget _buildMeetingSchedule() {
    return Row(
      children: [
        Expanded(
          child: _buildScheduleButton(
            icon: Icons.calendar_month_rounded,
            title: 'Preferred Date',
            value: _meetingDate == null
                ? 'Select date'
                : _formatDate(_meetingDate!),
            onTap: _pickMeetingDate,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildScheduleButton(
            icon: Icons.access_time_rounded,
            title: 'Preferred Time',
            value: _meetingTime == null
                ? 'Select time'
                : _meetingTime!.format(context),
            onTap: _pickMeetingTime,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SCHEDULE BUTTON
  // ===========================================================================

  Widget _buildScheduleButton({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final bool selected = value != 'Select date' && value != 'Select time';

    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? _primary : _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _softPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primary, size: 18),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textGrey,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _textDark : _textGrey,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DESCRIPTION
  // ===========================================================================

  Widget _buildDescriptionField() {
    String hint;

    switch (_selectedType) {
      case 'App Problem':
        hint =
            'Explain what went wrong, what you were trying to do, and what happened...';
        break;

      case 'Suggestion':
        hint =
            'Tell us your idea and how it could improve the hostel or app...';
        break;

      case 'Meeting':
        hint = 'What would you like to discuss in the meeting?';
        break;

      case 'Complaint':
      default:
        hint = 'Provide details about the issue...';
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: TextFormField(
        controller: _descriptionController,
        enabled: !_isLoading,
        minLines: 5,
        maxLines: 8,
        maxLength: 1000,
        keyboardType: TextInputType.multiline,
        style: TextStyle(color: _textDark, fontSize: 10.5, height: 1.45),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _isDark ? const Color(0xFF777D89) : const Color(0xFF9CA3AF),
            fontSize: 10,
            height: 1.45,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 75),
            child: Icon(Icons.edit_note_rounded, color: _primary, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          border: InputBorder.none,
          counterStyle: TextStyle(color: _textGrey, fontSize: 8),
          contentPadding: const EdgeInsets.fromLTRB(5, 13, 13, 5),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please provide some details';
          }

          if (value.trim().length < 5) {
            return 'Please provide a little more detail';
          }

          return null;
        },
      ),
    );
  }

  // ===========================================================================
  // ATTACHMENT
  // ===========================================================================

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attachment',
              style: TextStyle(
                color: _textDark,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(width: 6),

            Text('(Optional)', style: TextStyle(color: _textGrey, fontSize: 8)),
          ],
        ),

        const SizedBox(height: 8),

        if (_selectedImage == null)
          InkWell(
            onTap: _showImageSourceOptions,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: _softPrimary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: _primary,
                      size: 21,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Add Photo',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Take a photo or choose from gallery',
                    style: TextStyle(color: _textGrey, fontSize: 8),
                  ),
                ],
              ),
            ),
          )
        else
          _buildSelectedImage(),
      ],
    );
  }

  // ===========================================================================
  // SELECTED IMAGE
  // ===========================================================================

  Widget _buildSelectedImage() {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_selectedImage!, fit: BoxFit.cover),

          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'Attached',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 9,
            right: 9,
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: _danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUBMIT BUTTON
  // ===========================================================================

  Widget _buildSubmitButton() {
    String buttonText;

    switch (_selectedType) {
      case 'App Problem':
        buttonText = 'REPORT APP PROBLEM';
        break;

      case 'Suggestion':
        buttonText = 'SEND SUGGESTION';
        break;

      case 'Meeting':
        buttonText = 'REQUEST MEETING';
        break;

      case 'Complaint':
      default:
        buttonText = 'SUBMIT COMPLAINT';
    }

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedType == 'Meeting'
                        ? Icons.send_rounded
                        : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),

                  const SizedBox(width: 8),

                  Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // PRIVACY NOTE
  // ===========================================================================

  Widget _buildPrivacyNote() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, color: _textGrey, size: 12),

        const SizedBox(width: 4),

        Text(
          _selectedType == 'Meeting'
              ? 'Your request will be shared with the administration'
              : 'Please provide accurate information',
          style: TextStyle(color: _textGrey, fontSize: 7.5),
        ),
      ],
    );
  }

  // ===========================================================================
  // FIELD CONTAINER
  // ===========================================================================

  Widget _buildFieldContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  // ===========================================================================
  // FORM TITLE
  // ===========================================================================

  String _getFormTitle() {
    switch (_selectedType) {
      case 'App Problem':
        return 'App Problem Details';

      case 'Suggestion':
        return 'Suggestion Details';

      case 'Meeting':
        return 'Meeting Request';

      case 'Complaint':
      default:
        return 'Complaint Details';
    }
  }

  // ===========================================================================
  // SECTION SUBTITLE
  // ===========================================================================

  String _getSectionSubtitle() {
    switch (_selectedType) {
      case 'App Problem':
        return 'Tell us about the technical issue';

      case 'Suggestion':
        return 'Share your idea with us';

      case 'Meeting':
        return 'Choose a topic and preferred schedule';

      case 'Complaint':
      default:
        return 'Tell us what went wrong';
    }
  }

  // ===========================================================================
  // DATE FORMAT
  // ===========================================================================

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} '
        '${_monthName(date.month)} '
        '${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}
