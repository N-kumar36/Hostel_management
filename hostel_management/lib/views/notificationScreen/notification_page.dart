import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:HostelMess/services/api_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final ApiService api = ApiService();

  bool isLoading = true;
  bool isMarkingAllRead = false;

  List<Map<String, dynamic>> notifications = [];

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _background = Color(0xFFF6F7FB);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final res = await api.getNotifications();

      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'];

        setState(() {
          notifications = data is List
              ? data
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : [];
        });
      } else {
        _showMessage(
          res['message']?.toString() ?? 'Unable to load notifications.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Notification fetch error: $e');

      if (mounted) {
        _showMessage('Unable to load notifications.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  int get _unreadCount =>
      notifications.where((item) => item['isRead'] != true).length;

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (item['isRead'] == true) return;

    final id = item['_id']?.toString() ?? item['id']?.toString();

    if (id == null || id.isEmpty) return;

    setState(() => item['isRead'] = true);

    try {
      final success = await api.markNotificationRead(id);

      if (!success && mounted) {
        setState(() => item['isRead'] = false);
        _showMessage('Could not update notification status.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => item['isRead'] = false);
      _showMessage('Could not update notification status.', isError: true);
    }
  }

  Future<void> _markAllAsRead() async {
    if (isMarkingAllRead || _unreadCount == 0) return;

    final oldStates = notifications
        .map((item) => item['isRead'] == true)
        .toList();

    setState(() {
      isMarkingAllRead = true;

      for (final item in notifications) {
        item['isRead'] = true;
      }
    });

    try {
      final success = await api.markAllNotificationsRead();

      if (!mounted) return;

      if (!success) {
        setState(() {
          for (int i = 0; i < notifications.length; i++) {
            notifications[i]['isRead'] = oldStates[i];
          }
        });

        _showMessage('Failed to mark notifications as read.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        for (int i = 0; i < notifications.length; i++) {
          notifications[i]['isRead'] = oldStates[i];
        }
      });

      _showMessage('Failed to update notifications.', isError: true);
    } finally {
      if (mounted) {
        setState(() => isMarkingAllRead = false);
      }
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> item) async {
    final index = notifications.indexOf(item);
    if (index == -1) return;

    final id = item['_id']?.toString() ?? item['id']?.toString();

    if (id == null || id.isEmpty) {
      _showMessage('Unable to delete this notification.', isError: true);
      return;
    }

    final deletedItem = Map<String, dynamic>.from(item);

    setState(() => notifications.removeAt(index));

    try {
      final success = await api.deleteNotification(id);

      if (!mounted) return;

      if (!success) {
        _restoreNotification(deletedItem, index);
        _showMessage('Failed to delete notification.', isError: true);
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => _restoreNotification(deletedItem, index),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _restoreNotification(deletedItem, index);
      _showMessage('Failed to delete notification.', isError: true);
    }
  }

  void _restoreNotification(Map<String, dynamic> item, int index) {
    if (!mounted) return;

    setState(() {
      if (notifications.any(
        (existing) =>
            (existing['_id'] ?? existing['id']) == (item['_id'] ?? item['id']),
      )) {
        return;
      }

      if (index <= notifications.length) {
        notifications.insert(index, item);
      } else {
        notifications.add(item);
      }
    });
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text(
          'This notification will be removed from your account.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteNotification(item);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF15803D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime time) {
    final difference = DateTime.now().difference(time);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(time)}';
    }

    if (difference.inDays < 7) {
      return DateFormat('EEE, hh:mm a').format(time);
    }

    return DateFormat('dd MMM, hh:mm a').format(time);
  }

  _NotificationStyle _notificationStyle(dynamic type) {
    switch (type?.toString()) {
      case 'vote':
        return const _NotificationStyle(
          Icons.how_to_vote_rounded,
          Color(0xFFD97706),
        );

      case 'payment':
        return const _NotificationStyle(
          Icons.account_balance_wallet_rounded,
          Color(0xFF16A34A),
        );

      case 'served':
      case 'meal_served':
      case 'take_your_meal':
        return const _NotificationStyle(
          Icons.restaurant_rounded,
          Color(0xFF2563EB),
        );

      case 'meal_cancelled':
        return const _NotificationStyle(
          Icons.no_meals_rounded,
          Color(0xFFDC2626),
        );

      case 'meal_balance_warning':
        return const _NotificationStyle(
          Icons.warning_amber_rounded,
          Color(0xFFD97706),
        );

      case 'new_cycle':
        return const _NotificationStyle(
          Icons.autorenew_rounded,
          Color(0xFF6366F1),
        );

      case 'meeting_arranged':
        return const _NotificationStyle(
          Icons.groups_rounded,
          Color(0xFF7C3AED),
        );

      default:
        return const _NotificationStyle(
          Icons.notifications_active_rounded,
          _primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : _background,
        foregroundColor: theme.colorScheme.onSurface,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            SizedBox(height: 3),
            Text(
              'Your latest hostel updates',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: isMarkingAllRead
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Mark all as read',
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all_rounded),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: _primary,
                onRefresh: _fetchNotifications,
                child: notifications.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [
                          _buildSummaryCard(theme),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Text(
                                'Recent activity',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${notifications.length} total',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...notifications.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _buildNotificationCard(item, theme),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.17),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _unreadCount == 0 ? 'You are all caught up!' : 'Stay updated',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _unreadCount == 0
                      ? 'No unread notifications.'
                      : 'You have $_unreadCount unread '
                            '${_unreadCount == 1 ? 'notification' : 'notifications'}.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item, ThemeData theme) {
    final isRead = item['isRead'] == true;
    final style = _notificationStyle(item['type']);
    final time = _parseDate(item['createdAt']);

    return Dismissible(
      key: ValueKey(
        item['_id'] ?? item['id'] ?? '${item['createdAt']}_${item['title']}',
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(item);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: !isRead
                ? _primary.withOpacity(0.30)
                : theme.dividerColor.withOpacity(0.55),
            width: !isRead ? 1.3 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.08 : 0.025,
              ),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _markAsRead(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(isRead ? 0.08 : 0.13),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    style.icon,
                    color: style.color.withOpacity(isRead ? 0.7 : 1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['title']?.toString() ?? 'Notification',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.3,
                                color: theme.colorScheme.onSurface,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            tooltip: 'More options',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (value) {
                              if (value == 'read') {
                                _markAsRead(item);
                              } else if (value == 'delete') {
                                _confirmDelete(item);
                              }
                            },
                            itemBuilder: (_) => [
                              if (!isRead)
                                const PopupMenuItem(
                                  value: 'read',
                                  child: Row(
                                    children: [
                                      Icon(Icons.done_rounded, size: 19),
                                      SizedBox(width: 10),
                                      Text('Mark as read'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 19,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item['message']?.toString() ?? '',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _formatDate(time),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? theme.dividerColor.withOpacity(0.3)
                                  : _primary.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRead ? 'READ' : 'UNREAD',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isRead
                                    ? theme.colorScheme.onSurfaceVariant
                                    : _primary,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.09),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: _primary,
            size: 55,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'All caught up!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'You have no notifications right now.\n'
          'Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: _fetchNotifications,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }
}

class _NotificationStyle {
  final IconData icon;
  final Color color;

  const _NotificationStyle(this.icon, this.color);
}
