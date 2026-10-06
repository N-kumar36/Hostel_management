import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:HostelMess/services/api_service.dart';

class PollingPage extends StatefulWidget {
  const PollingPage({super.key});

  @override
  State<PollingPage> createState() => _PollingPageState();
}

class _PollingPageState extends State<PollingPage> {
  final ApiService api = ApiService();

  List<dynamic> _polls = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  final Set<String> _votingPollIds = {};

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadPolls();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD POLLS
  // ============================================================

  Future<void> _loadPolls({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
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
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = "Unable to load polls.";
      });
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
    if (date == null) return "Not specified";

    return DateFormat("dd MMM yyyy • hh:mm a").format(date);
  }

  String _remainingTime(DateTime endAt) {
    final difference = endAt.difference(DateTime.now());

    if (difference.isNegative || difference.inSeconds <= 0) {
      return "Voting ended";
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
      return "${days}d ${hours}h ${minutes}m left";
    }

    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s left";
    }

    if (minutes > 0) {
      return "${minutes}m ${seconds}s left";
    }

    return "${seconds}s left";
  }

  // ============================================================
  // STATUS
  // ============================================================

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

  Color _getStatusColor(String status) {
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

  String _getStatusText(String status) {
    switch (status) {
      case "active":
        return "ACTIVE";

      case "scheduled":
        return "UPCOMING";

      case "closed":
        return "CLOSED";

      default:
        return status.toUpperCase();
    }
  }

  // ============================================================
  // VOTE
  // ============================================================

  Future<void> _submitVote(
    Map<String, dynamic> poll,
    Map<String, dynamic> option,
  ) async {
    final String? pollId = poll['_id']?.toString();

    final String? optionId = option['_id']?.toString();

    if (pollId == null ||
        pollId.isEmpty ||
        optionId == null ||
        optionId.isEmpty) {
      _showSnackBar("Invalid poll or option.", Colors.red);
      return;
    }

    if (_getStatus(poll) != "active") {
      _showSnackBar("Voting is no longer active.", Colors.orange);
      return;
    }

    final bool? confirmed = await _showVoteConfirmation(
      option['text']?.toString() ?? "Selected option",
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _votingPollIds.add(pollId);
    });

    try {
      final response = await api.voteOnPoll(pollId: pollId, optionId: optionId);

      if (!mounted) return;

      if (response['success'] == true) {
        _showSnackBar("Vote submitted successfully.", const Color(0xFF16A34A));

        await _loadPolls(refresh: true);
      } else {
        _showSnackBar(
          response['message']?.toString() ?? "Unable to submit vote.",
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar("Unable to submit vote.", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _votingPollIds.remove(pollId);
        });
      }
    }
  }

  Future<bool?> _showVoteConfirmation(String optionText) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Confirm Your Vote",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You are voting for:",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  optionText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "You can vote only once in this poll. "
                "Your vote cannot be changed later.",
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text("CANCEL"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text("CAST VOTE"),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // RESULTS
  // ============================================================

  Future<void> _openResults(Map<String, dynamic> poll) async {
    final String? pollId = poll['_id']?.toString();

    if (pollId == null || pollId.isEmpty) {
      return;
    }

    _showLoadingDialog();

    try {
      final result = await api.getPollResults(pollId);

      if (!mounted) return;

      Navigator.of(context).pop();

      if (result == null) {
        _showSnackBar("Results are not available yet.", Colors.orange);
        return;
      }

      _showResultsSheet(result);
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showSnackBar("Unable to load results.", Colors.red);
    }
  }

  void _showResultsSheet(Map<String, dynamic> result) {
    final theme = Theme.of(context);

    final List<dynamic> results = result['results'] is List
        ? result['results']
        : [];

    final List<dynamic> winners = result['winners'] is List
        ? result['winners']
        : [];

    final dynamic decision = result['decision'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Voting Results",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "${result['totalVotes'] ?? 0} total votes",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            "No votes recorded.",
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          children: [
                            ...results.map((dynamic raw) {
                              final item = Map<String, dynamic>.from(raw);

                              final int votes =
                                  int.tryParse(
                                    item['votes']?.toString() ?? "0",
                                  ) ??
                                  0;

                              final double percentage =
                                  double.tryParse(
                                    item['percentage']?.toString() ?? "0",
                                  ) ??
                                  0;

                              final bool winner = winners.any(
                                (dynamic w) =>
                                    w['optionId']?.toString() ==
                                    item['optionId']?.toString(),
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildResultCard(
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

  Widget _buildResultCard(
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
              ? const Color(0xFF16A34A).withOpacity(0.35)
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "${percentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 13,
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
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFF16A34A),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "FINAL DECISION",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                    letterSpacing: 0.5,
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
  // POLL CARD
  // ============================================================

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final theme = Theme.of(context);

    final String status = _getStatus(poll);

    final Color statusColor = _getStatusColor(status);

    final DateTime? startAt = _parseDate(poll['startAt']);

    final DateTime? endAt = _parseDate(poll['endAt']);

    final bool hasVoted = poll['hasVoted'] == true;

    final String pollId = poll['_id']?.toString() ?? "";

    final bool voting = _votingPollIds.contains(pollId);

    final String title = poll['title']?.toString() ?? "Untitled Poll";

    final String description = poll['description']?.toString() ?? "";

    final List<dynamic> options = poll['options'] is List
        ? poll['options']
        : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.14 : 0.04,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
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
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // DESCRIPTION
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // TIME INFORMATION
          if (startAt != null)
            _buildTimeRow(
              Icons.play_circle_outline_rounded,
              "Starts",
              _formatDate(startAt),
            ),

          if (endAt != null) ...[
            const SizedBox(height: 7),
            _buildTimeRow(
              status == "active" ? Icons.timer_outlined : Icons.event_rounded,
              status == "active" ? "Remaining" : "Ends",
              status == "active" ? _remainingTime(endAt) : _formatDate(endAt),
              active: status == "active",
            ),
          ],

          const SizedBox(height: 18),

          // CONTENT
          if (status == "active" && !hasVoted)
            _buildOptions(poll, options, voting)
          else if (status == "active" && hasVoted)
            _buildAlreadyVoted()
          else if (status == "scheduled")
            _buildUpcoming(startAt)
          else if (status == "closed")
            _buildClosed(poll),
        ],
      ),
    );
  }

  Widget _buildTimeRow(
    IconData icon,
    String title,
    String value, {
    bool active = false,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: active
              ? const Color(0xFFD97706)
              : theme.colorScheme.onSurfaceVariant,
        ),
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
              color: active
                  ? const Color(0xFFD97706)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OPTIONS
  // ============================================================

  Widget _buildOptions(
    Map<String, dynamic> poll,
    List<dynamic> options,
    bool voting,
  ) {
    if (options.isEmpty) {
      return const Text("No voting options available.");
    }

    return Column(
      children: [
        ...options.map((dynamic rawOption) {
          final option = Map<String, dynamic>.from(rawOption);

          final String text = option['text']?.toString() ?? "Option";

          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: voting ? null : () => _submitVote(poll, option),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (voting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // STATES
  // ============================================================

  Widget _buildAlreadyVoted() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You have already voted in this poll.",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcoming(DateTime? startAt) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              startAt == null
                  ? "Voting has not started yet."
                  : "Voting starts ${_formatDate(startAt)}.",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosed(Map<String, dynamic> poll) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_clock_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Voting has ended.",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openResults(poll),
            icon: const Icon(Icons.bar_chart_rounded),
            label: const Text("VIEW RESULTS"),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.how_to_vote_outlined,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "No Polls Available",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "There are currently no voting activities available.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
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

    final List<dynamic> activePolls = _polls.where((poll) {
      return _getStatus(Map<String, dynamic>.from(poll)) == "active";
    }).toList();

    final List<dynamic> upcomingPolls = _polls.where((poll) {
      return _getStatus(Map<String, dynamic>.from(poll)) == "scheduled";
    }).toList();

    final List<dynamic> closedPolls = _polls.where((poll) {
      return _getStatus(Map<String, dynamic>.from(poll)) == "closed";
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Text(
          "Voting",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _isRefreshing ? null : () => _loadPolls(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: () => _loadPolls(refresh: true),
              child: _polls.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                      children: [
                        // HEADER
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.25,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: const Icon(
                                  Icons.how_to_vote_rounded,
                                  color: Colors.white,
                                  size: 29,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Student Voting",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      activePolls.isEmpty
                                          ? "No active voting right now"
                                          : "${activePolls.length} active poll${activePolls.length == 1 ? '' : 's'} available",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (activePolls.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            "Active Polls",
                            Icons.radio_button_checked,
                            const Color(0xFF16A34A),
                            activePolls.length,
                          ),
                          const SizedBox(height: 12),
                          ...activePolls.map(
                            (poll) =>
                                _buildPollCard(Map<String, dynamic>.from(poll)),
                          ),
                        ],

                        if (upcomingPolls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildSectionHeader(
                            "Upcoming Polls",
                            Icons.schedule_rounded,
                            const Color(0xFFD97706),
                            upcomingPolls.length,
                          ),
                          const SizedBox(height: 12),
                          ...upcomingPolls.map(
                            (poll) =>
                                _buildPollCard(Map<String, dynamic>.from(poll)),
                          ),
                        ],

                        if (closedPolls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildSectionHeader(
                            "Past Polls",
                            Icons.history_rounded,
                            Colors.grey,
                            closedPolls.length,
                          ),
                          const SizedBox(height: 12),
                          ...closedPolls.map(
                            (poll) =>
                                _buildPollCard(Map<String, dynamic>.from(poll)),
                          ),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? "Something went wrong.",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _loadPolls(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("RETRY"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
