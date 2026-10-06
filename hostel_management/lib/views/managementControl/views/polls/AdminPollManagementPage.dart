import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class AdminPollManagementPage extends StatefulWidget {
  const AdminPollManagementPage({super.key});

  @override
  State<AdminPollManagementPage> createState() =>
      _AdminPollManagementPageState();
}

class _AdminPollManagementPageState extends State<AdminPollManagementPage> {
  final ApiService api = ApiService();

  List<dynamic> _polls = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  // ============================================================
  // LOAD POLLS
  // ============================================================

  Future<void> _loadPolls({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final polls = await api.getPolls();

      if (!mounted) return;

      setState(() {
        _polls = polls;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint("Admin Poll Load Error: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showSnackBar("Unable to load polls.", Colors.red);
    }
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is Map) {
      final dynamic dateValue = value['\$date'];

      if (dateValue != null) {
        return DateTime.tryParse(dateValue.toString())?.toLocal();
      }
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return "Not specified";
    }

    return DateFormat("dd MMM yyyy • hh:mm a").format(date);
  }

  String _getStatus(Map<String, dynamic> poll) {
    final DateTime? startAt = _parseDate(poll['startAt']);

    final DateTime? endAt = _parseDate(poll['endAt']);

    final now = DateTime.now();

    if (startAt != null && now.isBefore(startAt)) {
      return "scheduled";
    }

    if (endAt != null && !now.isBefore(endAt)) {
      return "closed";
    }

    return "active";
  }

  Color _statusColor(String status) {
    switch (status) {
      case "active":
        return const Color(0xFF16A34A);

      case "scheduled":
        return const Color(0xFFD97706);

      case "closed":
        return const Color(0xFF6B7280);

      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case "active":
        return "ACTIVE";

      case "scheduled":
        return "SCHEDULED";

      case "closed":
        return "CLOSED";

      default:
        return status.toUpperCase();
    }
  }

  // ============================================================
  // CREATE POLL
  // ============================================================

  Future<void> _openCreatePoll() async {
    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return const _CreatePollSheet();
      },
    );

    if (created == true) {
      await _loadPolls(refresh: true);
    }
  }

  // ============================================================
  // RESULTS
  // ============================================================

  Future<void> _viewResults(Map<String, dynamic> poll) async {
    final pollId = poll['_id']?.toString();

    if (pollId == null || pollId.isEmpty) {
      return;
    }

    _showLoadingDialog();

    try {
      final result = await api.getPollResults(pollId);

      if (!mounted) return;

      Navigator.pop(context);

      if (result == null) {
        _showSnackBar("Results are not available.", Colors.orange);
        return;
      }

      _showResultsDialog(poll, result);
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      _showSnackBar("Unable to load results.", Colors.red);
    }
  }

  void _showResultsDialog(
    Map<String, dynamic> poll,
    Map<String, dynamic> result,
  ) {
    final theme = Theme.of(context);

    final List<dynamic> results = result['results'] is List
        ? result['results']
        : [];

    final List<dynamic> winners = result['winners'] is List
        ? result['winners']
        : [];

    final decision = result['decision'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          poll['title']?.toString() ?? "Poll Results",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildResultSummary(result),

                      const SizedBox(height: 18),

                      ...results.map((raw) {
                        final item = Map<String, dynamic>.from(raw);

                        final int votes =
                            int.tryParse(item['votes']?.toString() ?? "0") ?? 0;

                        final double percentage =
                            double.tryParse(
                              item['percentage']?.toString() ?? "0",
                            ) ??
                            0;

                        final bool winner = winners.any(
                          (w) =>
                              w['optionId']?.toString() ==
                              item['optionId']?.toString(),
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildResultItem(
                            item,
                            votes,
                            percentage,
                            winner,
                          ),
                        );
                      }),

                      if (decision is Map &&
                          decision['optionText'] != null) ...[
                        const SizedBox(height: 8),
                        _buildDecisionCard(decision),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultSummary(Map<String, dynamic> result) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.how_to_vote_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TOTAL VOTES",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "${result['totalVotes'] ?? 0}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(
    Map<String, dynamic> item,
    int votes,
    double percentage,
    bool winner,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: winner
              ? const Color(0xFF16A34A).withOpacity(0.4)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['text']?.toString() ?? "Option",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (winner)
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFD97706),
                ),
            ],
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.onSurface.withOpacity(0.07),
              valueColor: AlwaysStoppedAnimation<Color>(
                winner ? const Color(0xFF16A34A) : theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$votes votes",
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                "${percentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(Map decision) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_rounded,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "FINAL ADMIN DECISION",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  decision['optionText'].toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DELETE POLL
  // ============================================================

  Future<void> _deletePoll(Map<String, dynamic> poll) async {
    final String? pollId = poll['_id']?.toString();

    if (pollId == null || pollId.isEmpty) {
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Delete Poll?",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            "This will permanently delete the poll and all votes associated with it. This action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("CANCEL"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("DELETE"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final response = await api.deletePoll(pollId);

      if (!mounted) return;

      if (response['success'] == true) {
        _showSnackBar("Poll deleted successfully.", const Color(0xFF16A34A));

        await _loadPolls(refresh: true);
      } else {
        _showSnackBar(
          response['message']?.toString() ?? "Unable to delete poll.",
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar("Unable to delete poll.", Colors.red);
    }
  }

  // ============================================================
  // FINAL DECISION
  // ============================================================

  Future<void> _declareDecision(Map<String, dynamic> poll) async {
    final String status = _getStatus(poll);

    if (status != "closed") {
      _showSnackBar(
        "Final decision can only be declared after voting ends.",
        Colors.orange,
      );
      return;
    }

    final List<dynamic> options = poll['options'] is List
        ? poll['options']
        : [];

    if (options.isEmpty) return;

    final String? selectedOption = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? selected;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                "Declare Final Decision",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((raw) {
                    final option = Map<String, dynamic>.from(raw);

                    final String? id = option['_id']?.toString();

                    if (id == null || id.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return RadioListTile<String>(
                      value: id,
                      groupValue: selected,
                      title: Text(option['text']?.toString() ?? "Option"),
                      onChanged: (String? value) {
                        setDialogState(() {
                          selected = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("CANCEL"),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(dialogContext, selected),
                  child: const Text("DECLARE"),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedOption == null) {
      return;
    }

    try {
      final response = await api.declarePollDecision(
        pollId: poll['_id'].toString(),
        optionId: selectedOption,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _showSnackBar("Final decision declared.", const Color(0xFF16A34A));

        await _loadPolls(refresh: true);
      } else {
        _showSnackBar(
          response['message']?.toString() ?? "Unable to declare decision.",
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar("Unable to declare decision.", Colors.red);
    }
  }

  // ============================================================
  // POLL CARD
  // ============================================================

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final theme = Theme.of(context);

    final String status = _getStatus(poll);

    final Color statusColor = _statusColor(status);

    final DateTime? startAt = _parseDate(poll['startAt']);

    final DateTime? endAt = _parseDate(poll['endAt']);

    final List<dynamic> options = poll['options'] is List
        ? poll['options']
        : [];

    final bool hasDecision =
        poll['decision'] is Map && poll['decision']['optionText'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.12 : 0.035,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.how_to_vote_rounded,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poll['title']?.toString() ?? "Untitled Poll",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusText(status),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "delete") {
                    _deletePoll(poll);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                        ),
                        SizedBox(width: 8),
                        Text("Delete"),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          if ((poll['description']?.toString() ?? "").isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              poll['description'].toString(),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 15),

          _infoRow(
            Icons.play_circle_outline_rounded,
            "Starts",
            _formatDate(startAt),
          ),

          const SizedBox(height: 7),

          _infoRow(Icons.event_rounded, "Ends", _formatDate(endAt)),

          const SizedBox(height: 14),

          Row(
            children: [
              _miniStat(Icons.list_alt_rounded, "${options.length}", "Options"),
              const SizedBox(width: 8),
              _miniStat(
                Icons.people_alt_outlined,
                "${poll['totalVotes'] ?? 0}",
                "Votes",
              ),
            ],
          ),

          if (hasDecision) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 20,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Decision: ${poll['decision']['optionText']}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewResults(poll),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text("RESULTS"),
                ),
              ),

              if (status == "closed" && !hasDecision) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _declareDecision(poll),
                    icon: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 18,
                    ),
                    label: const Text("DECIDE"),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Text(
          "$title:",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final int activeCount = _polls.where((p) {
      return _getStatus(Map<String, dynamic>.from(p)) == "active";
    }).length;

    final int scheduledCount = _polls.where((p) {
      return _getStatus(Map<String, dynamic>.from(p)) == "scheduled";
    }).length;

    final int closedCount = _polls.where((p) {
      return _getStatus(Map<String, dynamic>.from(p)) == "closed";
    }).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Text(
          "Poll Management",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : () => _loadPolls(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePoll,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Create Poll"),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPolls(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                children: [
                  _buildHeader(activeCount, scheduledCount, closedCount),

                  const SizedBox(height: 22),

                  if (_polls.isEmpty)
                    _buildEmptyState()
                  else
                    ..._polls.map(
                      (poll) => _buildPollCard(Map<String, dynamic>.from(poll)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(int active, int scheduled, int closed) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5146E5), Color(0xFF3B32A0)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5146E5).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                "Voting Control",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Text(
            "Create, manage and review student polls.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _headerStat(active.toString(), "Active"),
              const SizedBox(width: 8),
              _headerStat(scheduled.toString(), "Upcoming"),
              const SizedBox(width: 8),
              _headerStat(closed.toString(), "Closed"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(
            Icons.how_to_vote_outlined,
            size: 60,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 15),
          Text(
            "No Polls Created",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            "Create your first student poll.",
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CREATE POLL SHEET
// ============================================================================

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final ApiService api = ApiService();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  DateTime? _startAt;
  DateTime? _endAt;

  bool _showResultsAfterClose = true;

  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    for (final controller in _optionControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // DATE TIME PICKER
  // ============================================================

  Future<void> _selectDateTime({required bool start}) async {
    final DateTime now = DateTime.now();

    final DateTime initial = start
        ? (_startAt ?? now)
        : (_endAt ?? _startAt ?? now.add(const Duration(hours: 1)));

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );

    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) {
      return;
    }

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (start) {
        _startAt = selected;
      } else {
        _endAt = selected;
      }
    });
  }

  // ============================================================
  // ADD OPTION
  // ============================================================

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      return;
    }

    final controller = _optionControllers.removeAt(index);

    controller.dispose();

    setState(() {});
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<void> _createPoll() async {
    final String title = _titleController.text.trim();

    final String description = _descriptionController.text.trim();

    final List<String> options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (title.isEmpty) {
      _showError("Please enter a poll title.");
      return;
    }

    if (options.length < 2) {
      _showError("Please provide at least two options.");
      return;
    }

    if (_startAt == null) {
      _showError("Please select the start date and time.");
      return;
    }

    if (_endAt == null) {
      _showError("Please select the end date and time.");
      return;
    }

    if (!_endAt!.isAfter(_startAt!)) {
      _showError("End time must be after start time.");
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final response = await api.createPoll(
        title: title,
        description: description,
        options: options,
        startAt: _startAt!,
        endAt: _endAt!,
        showResultsAfterClose: _showResultsAfterClose,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showError(response['message']?.toString() ?? "Unable to create poll.");
      }
    } catch (e) {
      _showError("Unable to create poll.");
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _dateText(DateTime? date) {
    if (date == null) {
      return "Select date & time";
    }

    return DateFormat("dd MMM yyyy • hh:mm a").format(date);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.add_task_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Create New Poll",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                children: [
                  _label("Poll Title"),

                  const SizedBox(height: 7),

                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      "Enter poll title",
                      Icons.title_rounded,
                    ),
                  ),

                  const SizedBox(height: 17),

                  _label("Description"),

                  const SizedBox(height: 7),

                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      "Explain what students are voting on",
                      Icons.description_outlined,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _label("Voting Options")),
                      TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("Add"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  ...List.generate(_optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.08,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: TextField(
                              controller: _optionControllers[index],
                              decoration: _inputDecoration(
                                "Option ${index + 1}",
                                Icons.radio_button_unchecked,
                              ),
                            ),
                          ),

                          if (_optionControllers.length > 2)
                            IconButton(
                              onPressed: () => _removeOption(index),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  _label("Voting Schedule"),

                  const SizedBox(height: 9),

                  _dateTimeButton(
                    icon: Icons.play_circle_outline_rounded,
                    title: "Start Voting",
                    value: _dateText(_startAt),
                    onTap: () => _selectDateTime(start: true),
                  ),

                  const SizedBox(height: 9),

                  _dateTimeButton(
                    icon: Icons.stop_circle_outlined,
                    title: "End Voting",
                    value: _dateText(_endAt),
                    onTap: () => _selectDateTime(start: false),
                  ),

                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showResultsAfterClose,
                    onChanged: (value) {
                      setState(() {
                        _showResultsAfterClose = value;
                      });
                    },
                    title: const Text(
                      "Show results after voting ends",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      "Students can view the final vote results.",
                      style: TextStyle(fontSize: 11),
                    ),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isCreating ? null : _createPoll,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.publish_rounded),
                      label: Text(_isCreating ? "CREATING..." : "CREATE POLL"),
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

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final theme = Theme.of(context);

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 19),
      filled: true,
      fillColor: theme.colorScheme.onSurface.withOpacity(0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _dateTimeButton({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.onSurface.withOpacity(0.035),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.calendar_month_rounded,
                size: 19,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
