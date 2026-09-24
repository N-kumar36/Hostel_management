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

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // ============================================================
  // FETCH
  // ============================================================

  Future<void> _fetchNotifications() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

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
          res['message']?.toString() ?? 'Unable to load notifications',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Notification fetch error: $e');

      if (mounted) {
        _showMessage('Unable to load notifications', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MARK ONE AS READ
  // ============================================================

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (item['isRead'] == true) return;

    final notificationId = item['_id']?.toString() ?? item['id']?.toString();

    if (notificationId == null || notificationId.isEmpty) {
      return;
    }

    setState(() {
      item['isRead'] = true;
    });

    final success = await api.markNotificationRead(notificationId);

    if (!success && mounted) {
      setState(() {
        item['isRead'] = false;
      });

      _showMessage('Could not update notification status', isError: true);
    }
  }

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<void> _markAllAsRead() async {
    if (isMarkingAllRead) return;

    final unreadExists = notifications.any((item) => item['isRead'] != true);

    if (!unreadExists) return;

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

      if (!success && mounted) {
        setState(() {
          for (int i = 0; i < notifications.length; i++) {
            notifications[i]['isRead'] = oldStates[i];
          }
        });

        _showMessage('Failed to mark notifications as read', isError: true);
      }
    } catch (e) {
      debugPrint('Mark all read error: $e');

      if (mounted) {
        setState(() {
          for (int i = 0; i < notifications.length; i++) {
            notifications[i]['isRead'] = oldStates[i];
          }
        });

        _showMessage('Failed to update notifications', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          isMarkingAllRead = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteNotification(
    Map<String, dynamic> item, {
    bool showUndo = true,
  }) async {
    final index = notifications.indexOf(item);

    if (index == -1) return;

    final deletedItem = Map<String, dynamic>.from(item);

    final notificationId = item['_id']?.toString() ?? item['id']?.toString();

    if (notificationId == null || notificationId.isEmpty) {
      _showMessage('Unable to delete this notification', isError: true);
      return;
    }

    setState(() {
      notifications.removeAt(index);
    });

    try {
      final success = await api.deleteNotification(notificationId);

      if (!success) {
        if (mounted) {
          setState(() {
            if (index <= notifications.length) {
              notifications.insert(index, deletedItem);
            } else {
              notifications.add(deletedItem);
            }
          });

          _showMessage('Failed to delete notification', isError: true);
        }

        return;
      }

      if (showUndo && mounted) {
        _showUndoSnackbar(deletedItem, index);
      }
    } catch (e) {
      debugPrint('Delete notification error: $e');

      if (mounted) {
        setState(() {
          if (index <= notifications.length) {
            notifications.insert(index, deletedItem);
          } else {
            notifications.add(deletedItem);
          }
        });

        _showMessage('Failed to delete notification', isError: true);
      }
    }
  }

  // ============================================================
  // UNDO
  // ============================================================

  void _showUndoSnackbar(Map<String, dynamic> item, int index) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF151B2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Notification deleted',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                setState(() {
                  if (index <= notifications.length) {
                    notifications.insert(index, item);
                  } else {
                    notifications.add(item);
                  }
                });
              },
              child: const Text(
                'UNDO',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONFIRM DELETE
  // ============================================================

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete notification?',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This notification will be removed from your account.',
            style: TextStyle(color: Colors.grey[600], height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteNotification(item);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications
        .where((item) => item['isRead'] != true)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(unreadCount),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: _fetchNotifications,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildNotificationCard(notifications[index]),
                  );
                },
              ),
            ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(int unreadCount) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      centerTitle: false,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            unreadCount == 0
                ? 'You are all caught up'
                : '$unreadCount unread notification'
                      '${unreadCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 11,
              color: unreadCount == 0 ? Colors.grey : const Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        // ======================================================
        // MARK ALL READ
        // ======================================================
        if (unreadCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: isMarkingAllRead
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all_rounded, size: 17),
                    label: const Text(
                      'Read all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                    ),
                  ),
          ),
      ],
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isRead = item['isRead'] == true;

    final style = _notificationStyle(item['type']);

    final time = _parseDate(item['createdAt']);

    return Dismissible(
      key: ValueKey(
        item['_id'] ?? item['id'] ?? '${item['createdAt']}_${item['title']}',
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteNotification(item);
        return false;
      },
      background: _buildDeleteBackground(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead ? const Color(0xFFE5E7EB) : const Color(0xFFD8D9FF),
            width: isRead ? 1 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isRead ? .035 : .055),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _markAsRead(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(style, isRead),
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
                                color: const Color(0xFF111827),
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(isRead),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['message']?.toString() ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: isRead
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatNotificationDate(time),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          _buildMoreButton(item),
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

  // ============================================================
  // ICON
  // ============================================================

  Widget _buildNotificationIcon(NotificationStyle style, bool isRead) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: style.color.withOpacity(isRead ? .07 : .12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        style.icon,
        color: style.color.withOpacity(isRead ? .65 : 1),
        size: 23,
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatusBadge(bool isRead) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF3F4F6) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isRead ? Colors.grey[400] : const Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isRead ? 'READ' : 'UNREAD',
            style: TextStyle(
              color: isRead ? Colors.grey[500] : const Color(0xFF6366F1),
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MORE
  // ============================================================

  Widget _buildMoreButton(Map<String, dynamic> item) {
    return PopupMenuButton<String>(
      tooltip: 'Notification options',
      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey[400], size: 21),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'read') {
          _markAsRead(item);
        } else if (value == 'delete') {
          _confirmDelete(item);
        }
      },
      itemBuilder: (context) {
        final isRead = item['isRead'] == true;

        return [
          if (!isRead)
            const PopupMenuItem<String>(
              value: 'read',
              child: Row(
                children: [
                  Icon(Icons.done_rounded, color: Color(0xFF6366F1), size: 19),
                  SizedBox(width: 10),
                  Text(
                    'Mark as read',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 19,
                ),
                SizedBox(width: 10),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  // ============================================================
  // DELETE BACKGROUND
  // ============================================================

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 25),
          SizedBox(height: 3),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: const Color(0xFF6366F1),
      onRefresh: _fetchNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * .68,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(35),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'All caught up!',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'You have no notifications right now.\n'
                      'We will let you know when something happens.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATION TYPE
  // ============================================================

  NotificationStyle _notificationStyle(dynamic type) {
    switch (type?.toString()) {
      // Existing
      case 'vote':
        return const NotificationStyle(
          icon: Icons.how_to_vote_rounded,
          color: Color(0xFFF59E0B),
        );

      case 'payment':
        return const NotificationStyle(
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFF16A34A),
        );

      case 'served':
      case 'meal_served':
        return const NotificationStyle(
          icon: Icons.restaurant_rounded,
          color: Color(0xFF2563EB),
        );

      // New
      case 'meal_cancelled':
        return const NotificationStyle(
          icon: Icons.cancel_outlined,
          color: Color(0xFFDC2626),
        );

      case 'meal_balance_warning':
        return const NotificationStyle(
          icon: Icons.warning_amber_rounded,
          color: Color(0xFFD97706),
        );

      case 'new_cycle':
        return const NotificationStyle(
          icon: Icons.autorenew_rounded,
          color: Color(0xFF6366F1),
        );

      case 'meeting_arranged':
        return const NotificationStyle(
          icon: Icons.groups_rounded,
          color: Color(0xFF7C3AED),
        );

      case 'take_your_meal':
        return const NotificationStyle(
          icon: Icons.restaurant_menu_rounded,
          color: Color(0xFF2563EB),
        );

      default:
        return const NotificationStyle(
          icon: Icons.campaign_rounded,
          color: Color(0xFF6366F1),
        );
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatNotificationDate(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday, '
          '${DateFormat('hh:mm a').format(time)}';
    }

    if (difference.inDays < 7) {
      return DateFormat('EEE, hh:mm a').format(time);
    }

    return DateFormat('dd MMM, hh:mm a').format(time);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ================================================================
// NOTIFICATION STYLE
// ================================================================

class NotificationStyle {
  final IconData icon;
  final Color color;

  const NotificationStyle({required this.icon, required this.color});
}
