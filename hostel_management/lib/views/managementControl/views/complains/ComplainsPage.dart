import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:intl/intl.dart';

class ComplainsPage extends StatefulWidget {
  const ComplainsPage({super.key});

  @override
  State<ComplainsPage> createState() => _ComplainsPageState();
}

class _ComplainsPageState extends State<ComplainsPage> {
  // ===========================================================================
  // SERVICES
  // ===========================================================================

  final ApiService api = ApiService();

  // ===========================================================================
  // DATA
  // ===========================================================================

  List<dynamic> allComplains = [];

  bool isLoading = true;

  String selectedFilter = 'All';

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color _primary = Color(0xFF5B4FE9);
  static const Color _primaryDark = Color(0xFF4338CA);
  static const Color _background = Color(0xFFF7F8FC);

  static const Color _textDark = Color(0xFF111827);
  static const Color _textGrey = Color(0xFF6B7280);

  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFD97706);

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _fetchComplains();
  }

  // ===========================================================================
  // FETCH COMPLAINTS
  // ===========================================================================

  Future<void> _fetchComplains() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final data = await api.getComplains();

      if (!mounted) return;

      setState(() {
        allComplains = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching complaints: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showSnackBar('Unable to load requests.', _danger);
    }
  }

  // ===========================================================================
  // UPDATE STATUS
  // ===========================================================================

  Future<void> _updateStatus(String id, String newStatus) async {
    if (id.isEmpty) {
      _showSnackBar('Invalid request ID.', _danger);
      return;
    }

    try {
      final result = await api.updateComplainStatus(id, newStatus);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          final index = allComplains.indexWhere(
            (c) => c['_id']?.toString() == id,
          );

          if (index != -1) {
            allComplains[index]['status'] = newStatus;
          }
        });

        _showSnackBar(
          newStatus == 'Resolved'
              ? 'Request marked as resolved.'
              : 'Request rejected.',
          newStatus == 'Resolved' ? _success : _danger,
        );
      } else {
        _showSnackBar(
          result['message']?.toString() ?? 'Failed to update request.',
          _danger,
        );
      }
    } catch (e) {
      debugPrint('Update complaint status error: $e');

      if (!mounted) return;

      _showSnackBar('Failed to update request.', _danger);
    }
  }

  // ===========================================================================
  // IMAGE DIALOG
  // ===========================================================================

  void _showImageDialog(String imageUrl) {
    if (imageUrl.trim().isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(15),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.black,
                  constraints: const BoxConstraints(maxHeight: 650),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }

                        return const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 300,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 60,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // REQUEST TYPE
  // ===========================================================================
  //
  // NEW DATA:
  // complain['requestType']
  //
  // OLD DATA:
  // Request type was stored inside description.
  //
  // We support both so old requests don't break.
  // ===========================================================================

  String _getRequestType(Map<String, dynamic> complain) {
    final directType = complain['requestType']?.toString().trim();

    if (directType != null && directType.isNotEmpty) {
      return directType;
    }

    // -------------------------------------------------------------------------
    // BACKWARD COMPATIBILITY
    // -------------------------------------------------------------------------

    final description = complain['description']?.toString() ?? '';

    final upper = description.toUpperCase();

    if (upper.contains('REQUEST TYPE: MEETING')) {
      return 'Meeting';
    }

    if (upper.contains('REQUEST TYPE: APP PROBLEM')) {
      return 'App Problem';
    }

    if (upper.contains('REQUEST TYPE: SUGGESTION')) {
      return 'Suggestion';
    }

    return 'Complaint';
  }

  // ===========================================================================
  // TYPE COLOR
  // ===========================================================================

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return const Color(0xFF2563EB);

      case 'app problem':
        return const Color(0xFF7C3AED);

      case 'suggestion':
        return _warning;

      case 'complaint':
      default:
        return _danger;
    }
  }

  // ===========================================================================
  // TYPE ICON
  // ===========================================================================

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.groups_rounded;

      case 'app problem':
        return Icons.bug_report_rounded;

      case 'suggestion':
        return Icons.lightbulb_rounded;

      case 'complaint':
      default:
        return Icons.report_problem_rounded;
    }
  }

  // ===========================================================================
  // CATEGORY
  // ===========================================================================
  //
  // NEW DATA:
  // complain['category']
  //
  // Old requests are also supported.
  // ===========================================================================

  String _getDisplayCategory(Map<String, dynamic> complain) {
    final category = complain['category']?.toString().trim() ?? '';

    if (category.isNotEmpty) {
      return category;
    }

    // -------------------------------------------------------------------------
    // OLD DATA FALLBACK
    // -------------------------------------------------------------------------

    final description = complain['description']?.toString() ?? '';

    final type = _getRequestType(complain);

    if (type == 'Meeting') {
      final topic = _extractValue(description, 'MEETING TOPIC');

      if (topic.isNotEmpty) {
        return topic;
      }
    }

    if (type == 'App Problem') {
      final problem = _extractValue(description, 'PROBLEM CATEGORY');

      if (problem.isNotEmpty) {
        return problem;
      }
    }

    if (type == 'Suggestion') {
      final suggestion = _extractValue(description, 'SUGGESTION CATEGORY');

      if (suggestion.isNotEmpty) {
        return suggestion;
      }
    }

    final oldCategory = _extractValue(description, 'CATEGORY');

    if (oldCategory.isNotEmpty) {
      return oldCategory;
    }

    return 'General';
  }

  // ===========================================================================
  // EXTRACT OLD METADATA
  // ===========================================================================

  String _extractValue(String description, String key) {
    final lines = description.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.toUpperCase().startsWith(key.toUpperCase())) {
        final index = trimmed.indexOf(':');

        if (index != -1) {
          return trimmed.substring(index + 1).trim();
        }
      }
    }

    return '';
  }

  // ===========================================================================
  // MEETING DATE
  // ===========================================================================

  String _getMeetingDate(Map<String, dynamic> complain) {
    // -------------------------------------------------------------------------
    // NEW DATABASE FIELD
    // -------------------------------------------------------------------------

    final dynamic value = complain['meetingDate'];

    if (value != null && value.toString().trim().isNotEmpty) {
      try {
        final date = DateTime.parse(value.toString());

        return DateFormat('dd MMM yyyy').format(date.toLocal());
      } catch (_) {
        return value.toString();
      }
    }

    // -------------------------------------------------------------------------
    // OLD DESCRIPTION FALLBACK
    // -------------------------------------------------------------------------

    final description = complain['description']?.toString() ?? '';

    return _extractValue(description, 'PREFERRED DATE');
  }

  // ===========================================================================
  // MEETING TIME
  // ===========================================================================

  String _getMeetingTime(Map<String, dynamic> complain) {
    // -------------------------------------------------------------------------
    // NEW DATABASE FIELD
    // -------------------------------------------------------------------------

    final dynamic value = complain['meetingTime'];

    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }

    // -------------------------------------------------------------------------
    // OLD DESCRIPTION FALLBACK
    // -------------------------------------------------------------------------

    final description = complain['description']?.toString() ?? '';

    return _extractValue(description, 'PREFERRED TIME');
  }

  // ===========================================================================
  // CLEAN DESCRIPTION
  // ===========================================================================

  String _getReadableDescription(Map<String, dynamic> complain) {
    String text = complain['description']?.toString() ?? '';

    if (text.trim().isEmpty) {
      return 'No details provided.';
    }

    // -------------------------------------------------------------------------
    // NEW RECORDS
    // -------------------------------------------------------------------------
    //
    // New student page stores only the actual description.
    // Therefore normally nothing needs to be removed.
    //
    // -------------------------------------------------------------------------
    // OLD RECORDS
    // -------------------------------------------------------------------------

    final oldMetadataPatterns = [
      RegExp(r'REQUEST TYPE:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'CATEGORY:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'PROBLEM CATEGORY:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'SUGGESTION CATEGORY:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'MEETING TOPIC:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'PREFERRED DATE:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'PREFERRED TIME:\s*[^\n]*\n*', caseSensitive: false),
      RegExp(r'DISCUSSION TOPIC:\s*', caseSensitive: false),
      RegExp(r'DESCRIPTION:\s*', caseSensitive: false),
      RegExp(r'DETAILS:\s*', caseSensitive: false),
    ];

    for (final regex in oldMetadataPatterns) {
      text = text.replaceAll(regex, '');
    }

    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    if (text.isEmpty) {
      return 'No details provided.';
    }

    return text;
  }

  // ===========================================================================
  // CREATED DATE
  // ===========================================================================

  String _formatCreatedDate(dynamic createdAt) {
    if (createdAt == null) {
      return 'Unknown date';
    }

    try {
      final DateTime date = DateTime.parse(createdAt.toString());

      return DateFormat('MMM dd, yyyy • hh:mm a').format(date.toLocal());
    } catch (_) {
      return 'Unknown date';
    }
  }

  // ===========================================================================
  // STATUS COLOR
  // ===========================================================================

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return _success;

      case 'rejected':
        return _danger;

      case 'in progress':
        return _primary;

      case 'pending':
      default:
        return _warning;
    }
  }

  // ===========================================================================
  // FILTERED LIST
  // ===========================================================================

  List<dynamic> get _filteredComplains {
    if (selectedFilter == 'All') {
      return allComplains;
    }

    return allComplains.where((complain) {
      final status = complain['status']?.toString().toLowerCase() ?? '';

      return status == selectedFilter.toLowerCase();
    }).toList();
  }

  // ===========================================================================
  // STATUS COUNT
  // ===========================================================================

  int _countStatus(String status) {
    return allComplains.where((complain) {
      return (complain['status']?.toString().toLowerCase() ?? '') ==
          status.toLowerCase();
    }).length;
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
        titleSpacing: 18,

        title: const Column(
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
            SizedBox(height: 2),
            Text(
              'Manage student requests',
              style: TextStyle(
                color: _textGrey,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : _fetchComplains,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          _buildSummary(),

          const SizedBox(height: 8),

          _buildFilters(),

          const SizedBox(height: 5),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : _filteredComplains.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: _primary,
                    onRefresh: _fetchComplains,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                      itemCount: _filteredComplains.length,
                      itemBuilder: (context, index) {
                        final item = _filteredComplains[index];

                        return _buildComplainCard(
                          Map<String, dynamic>.from(item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Total',
              allComplains.length.toString(),
              Icons.support_agent_rounded,
              _primary,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: _summaryCard(
              'Pending',
              _countStatus('Pending').toString(),
              Icons.pending_actions_rounded,
              _warning,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: _summaryCard(
              'Resolved',
              _countStatus('Resolved').toString(),
              Icons.check_circle_rounded,
              _success,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: _summaryCard(
              'Rejected',
              _countStatus('Rejected').toString(),
              Icons.cancel_rounded,
              _danger,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUMMARY CARD
  // ===========================================================================

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E9F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),

          const SizedBox(height: 7),

          Text(
            value,
            style: const TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 1),

          Text(
            title,
            style: const TextStyle(
              color: _textGrey,
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 7),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Filter',
              style: TextStyle(
                color: _textDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(width: 9),

            _filterChip('All'),
            _filterGap(),
            _filterChip('Pending'),
            _filterGap(),
            _filterChip('Resolved'),
            _filterGap(),
            _filterChip('Rejected'),
          ],
        ),
      ),
    );
  }

  Widget _filterGap() {
    return const SizedBox(width: 7);
  }

  // ===========================================================================
  // FILTER CHIP
  // ===========================================================================

  Widget _filterChip(String label) {
    final bool selected = selectedFilter == label;

    Color color = _primary;

    if (label == 'Pending') {
      color = _warning;
    } else if (label == 'Resolved') {
      color = _success;
    } else if (label == 'Rejected') {
      color = _danger;
    }

    return InkWell(
      onTap: () {
        setState(() {
          selectedFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF5F5F8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _textGrey,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    final String title = selectedFilter == 'All'
        ? 'No requests yet'
        : 'No $selectedFilter requests';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEDFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, color: _primary, size: 38),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Student complaints, app problems, suggestions and meeting requests will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGrey, fontSize: 10, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPLAINT CARD
  // ===========================================================================

  Widget _buildComplainCard(Map<String, dynamic> complain) {
    final Map<String, dynamic> student = complain['studentId'] is Map
        ? Map<String, dynamic>.from(complain['studentId'])
        : <String, dynamic>{};

    final String status = complain['status']?.toString() ?? 'Pending';

    final bool isPending = status.toLowerCase() == 'pending';

    final String type = _getRequestType(complain);

    final Color typeColor = _getTypeColor(type);

    final Color statusColor = _getStatusColor(status);

    final String category = _getDisplayCategory(complain);

    final String description = _getReadableDescription(complain);

    final String imageUrl = complain['imageUrl']?.toString().trim() ?? '';

    final String studentName =
        student['name']?.toString().trim().isNotEmpty == true
        ? student['name'].toString()
        : 'Unknown Student';

    final String department = student['department']?.toString().trim() ?? '';

    final String regNum = student['regNum']?.toString().trim() ?? '';

    final String email = student['email']?.toString().trim() ?? '';

    final String phone = student['phone']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE7E8EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // STUDENT HEADER
            // ================================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStudentAvatar(student),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      if (department.isNotEmpty || regNum.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _studentSubTitle(department, regNum),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textGrey,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 8,
                          ),
                        ),
                      ],

                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 8,
                          ),
                        ),
                      ],

                      const SizedBox(height: 5),

                      Text(
                        _formatCreatedDate(complain['createdAt']),
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 7.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                _buildStatusBadge(status, statusColor),
              ],
            ),

            const SizedBox(height: 14),

            // ================================================================
            // REQUEST TYPE + CATEGORY
            // ================================================================
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.055),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: typeColor.withOpacity(0.13)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getTypeIcon(type), color: typeColor, size: 18),
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textGrey,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // MEETING DETAILS
            // ================================================================
            if (type == 'Meeting') _buildMeetingInfo(complain),

            const SizedBox(height: 13),

            // ================================================================
            // REQUEST DETAILS
            // ================================================================
            const Text(
              'REQUEST DETAILS',
              style: TextStyle(
                color: _textGrey,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 6),

            _buildReadableDescriptionBox(description),

            // ================================================================
            // IMAGE
            // ================================================================
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 13),
              _buildAttachment(imageUrl),
            ],

            // ================================================================
            // ACTIONS
            // ================================================================
            if (isPending) ...[
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmStatusChange(
                        complain['_id']?.toString() ?? '',
                        'Rejected',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _danger,
                        side: const BorderSide(color: _danger),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text(
                        'REJECT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmStatusChange(
                        complain['_id']?.toString() ?? '',
                        'Resolved',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 17,
                      ),
                      label: const Text(
                        'RESOLVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STUDENT SUBTITLE
  // ===========================================================================

  String _studentSubTitle(String department, String regNum) {
    if (department.isNotEmpty && regNum.isNotEmpty) {
      return '$department • Reg: $regNum';
    }

    if (department.isNotEmpty) {
      return department;
    }

    if (regNum.isNotEmpty) {
      return 'Reg: $regNum';
    }

    return '';
  }

  // ===========================================================================
  // STUDENT AVATAR
  // ===========================================================================

  Widget _buildStudentAvatar(Map<String, dynamic> student) {
    final String photo = student['photoURL']?.toString().trim() ?? '';

    if (photo.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFEEEDFF),
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (_, __) {},
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFEEEDFF),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_rounded, color: _primary, size: 24),
    );
  }

  // ===========================================================================
  // STATUS BADGE
  // ===========================================================================

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ===========================================================================
  // MEETING INFO
  // ===========================================================================

  Widget _buildMeetingInfo(Map<String, dynamic> complain) {
    final String date = _getMeetingDate(complain);

    final String time = _getMeetingTime(complain);

    if (date.isEmpty && time.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDDE7FF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: Color(0xFF2563EB),
            size: 19,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Row(
              children: [
                if (date.isNotEmpty)
                  Expanded(child: _meetingDetail('DATE', date)),

                if (date.isNotEmpty && time.isNotEmpty)
                  const SizedBox(width: 10),

                if (time.isNotEmpty)
                  Expanded(child: _meetingDetail('TIME', time)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MEETING DETAIL
  // ===========================================================================

  Widget _meetingDetail(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textGrey,
            fontSize: 7,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textDark,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DESCRIPTION BOX
  // ===========================================================================

  Widget _buildReadableDescriptionBox(String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        description,
        style: const TextStyle(
          color: _textDark,
          fontSize: 10.5,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ===========================================================================
  // ATTACHMENT
  // ===========================================================================

  Widget _buildAttachment(String imageUrl) {
    return GestureDetector(
      onTap: () => _showImageDialog(imageUrl),
      child: Container(
        height: 145,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: _textGrey,
                    size: 40,
                  ),
                );
              },
            ),

            Positioned(
              right: 9,
              bottom: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'VIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CONFIRM STATUS CHANGE
  // ===========================================================================

  Future<void> _confirmStatusChange(String id, String status) async {
    if (id.isEmpty) {
      _showSnackBar('Invalid request ID.', _danger);
      return;
    }

    final bool resolving = status == 'Resolved';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            resolving ? 'Resolve Request?' : 'Reject Request?',
            style: const TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            resolving
                ? 'This request will be marked as resolved.'
                : 'This request will be marked as rejected.',
            style: const TextStyle(
              color: _textGrey,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),

            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: resolving ? _success : _danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(resolving ? 'RESOLVE' : 'REJECT'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateStatus(id, status);
    }
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
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
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
