import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:HostelMess/services/api_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final ApiService api = ApiService();

  // ============================================================
  // WHATSAPP GROUP
  // ============================================================

  static const String _whatsappGroupUrl =
      'https://chat.whatsapp.com/Crg5tN4Dyox0kDSPaDXuOs?mode=gi_t';

  // ============================================================
  // STATE
  // ============================================================

  bool isLoading = true;
  bool isMarkingAllRead = false;
  bool isOpeningWhatsApp = false;

  List<Map<String, dynamic>> notifications = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // ============================================================
  // FETCH NOTIFICATIONS
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
  // UNDO DELETE
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
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Delete notification?',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This notification will be removed from your account.',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey[600],
              height: 1.4,
            ),
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
  // WHATSAPP QUICK MESSAGES
  // ============================================================

  List<WhatsAppMessage> get _quickWhatsAppMessages {
    return const [
      WhatsAppMessage(
        title: 'Take Your Meal',
        subtitle: 'Ask students to collect their meal',
        icon: Icons.restaurant_rounded,
        color: Color(0xFF16A34A),
        message:
            '🍛 TAKE YOUR MEAL\n\n'
            'Dear Students,\n'
            'Please take your meal now.\n\n'
            '— Hostel Mess Management',
      ),

      WhatsAppMessage(
        title: 'Gate Closing in 5 Minutes',
        subtitle: 'Urgent gate closing reminder',
        icon: Icons.door_front_door_rounded,
        color: Color(0xFFD97706),
        message:
            '🚨 GATE CLOSING ALERT\n\n'
            'Dear Students,\n'
            'The hostel mess gate will be closed in 5 minutes. '
            'Please come to the hostel mess immediately otherwise noone will responsible for your food.\n\n'
            '— Hostel Management',
      ),

      WhatsAppMessage(
        title: 'Gate Closed',
        subtitle: 'Inform students that the gate is closed',
        icon: Icons.lock_rounded,
        color: Color(0xFFDC2626),
        message:
            '🔒 GATE CLOSED\n\n'
            'Dear Students,\n'
            'The hostel mess gate is now closed.\n\n'
            '— Hostel Management',
      ),

      WhatsAppMessage(
        title: 'Meal Cancelled',
        subtitle: 'Notify students about meal cancellation',
        icon: Icons.no_meals_rounded,
        color: Color(0xFFDC2626),
        message:
            '❌ MEAL CANCELLED\n\n'
            'Dear Students,\n'
            'The scheduled meal has been cancelled.\n\n'
            'Please check the HostelMess app for further information.\n\n'
            '— Hostel Mess Management',
      ),

      WhatsAppMessage(
        title: 'Meal Started',
        subtitle: 'Tell students that new meal cycle has started',
        icon: Icons.restaurant_menu_rounded,
        color: Color(0xFF2563EB),
        message:
            '🍽️ MEAL STARTED\n\n'
            'Dear Students,\n'
            'new Meal cycle has started. Please select your meal pack then vote.\n\n'
            '— Hostel Mess Management',
      ),

      WhatsAppMessage(
        title: 'Meal Ending Soon',
        subtitle: 'Remind students before meal pack ends',
        icon: Icons.timer_rounded,
        color: Color(0xFF7C3AED),
        message:
            '⏰ MEAL ENDING SOON\n\n'
            'Dear Students,\n'
            'Meal package will end soon. Please complete your payments on time.\n\n'
            '— Hostel Mess Management',
      ),
    ];
  }

  // ============================================================
  // OPEN WHATSAPP GROUP
  // ============================================================

  Future<void> _sendWhatsAppMessage(String message) async {
    if (isOpeningWhatsApp) return;

    setState(() {
      isOpeningWhatsApp = true;
    });

    try {
      // Copy the selected message first.
      await Clipboard.setData(ClipboardData(text: message));

      final uri = Uri.parse(_whatsappGroupUrl);

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        if (mounted) {
          _showMessage(
            'WhatsApp could not be opened. '
            'The message has been copied.',
            isError: true,
          );
        }

        return;
      }

      if (mounted) {
        _showMessage('Message copied. Paste it in the group and send.');
      }
    } catch (e) {
      debugPrint('WhatsApp open error: $e');

      if (mounted) {
        _showMessage(
          'Could not open WhatsApp. '
          'The message has been copied.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isOpeningWhatsApp = false;
        });
      }
    }
  }

  // ============================================================
  // CUSTOM WHATSAPP MESSAGE
  // ============================================================

  Future<void> _showCustomWhatsAppMessageDialog() async {
    final controller = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_rounded, color: Color(0xFF25D366)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custom Message',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Write the message you want to send...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF20242C)
                  : const Color(0xFFF5F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isEmpty) {
                  return;
                }

                Navigator.pop(context, text);
              },
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Open WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (message != null && message.trim().isNotEmpty) {
      await _sendWhatsAppMessage(message.trim());
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(unreadCount),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _fetchNotifications,
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                      children: [
                        // ==================================================
                        // WHATSAPP
                        // AVAILABLE FOR EVERY USER
                        // ==================================================
                        _buildWhatsAppSection(),

                        const SizedBox(height: 20),

                        // ==================================================
                        // NOTIFICATIONS
                        // ==================================================
                        ...List.generate(notifications.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildNotificationCard(notifications[index]),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(int unreadCount) {
    final theme = Theme.of(context);

    final primary = theme.colorScheme.primary;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
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
              color: unreadCount == 0
                  ? theme.colorScheme.onSurfaceVariant
                  : primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        if (unreadCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: isMarkingAllRead
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                    style: TextButton.styleFrom(foregroundColor: primary),
                  ),
          ),
      ],
    );
  }

  // ============================================================
  // WHATSAPP SECTION
  // ============================================================

  Widget _buildWhatsAppSection() {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3038) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .12 : .035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========================================================
            // HEADER
            // ========================================================
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Quick Alerts',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Send an announcement to the hostel group',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ========================================================
            // QUICK MESSAGES
            // ========================================================
            ..._quickWhatsAppMessages.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _buildWhatsAppMessageTile(item),
              ),
            ),

            // ========================================================
            // CUSTOM MESSAGE
            // ========================================================
            InkWell(
              onTap: _showCustomWhatsAppMessageDialog,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(.07),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Message',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Write your own announcement',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ========================================================
            // INFORMATION
            // ========================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'The selected message is copied automatically. '
                    'WhatsApp will open the hostel group. '
                    'Paste the message and tap Send.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WHATSAPP TILE
  // ============================================================

  Widget _buildWhatsAppMessageTile(WhatsAppMessage item) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isOpeningWhatsApp
          ? null
          : () => _sendWhatsAppMessage(item.message),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: theme.dividerColor.withOpacity(.65)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 15),
                  SizedBox(width: 5),
                  Text(
                    'Send',
                    style: TextStyle(
                      color: Color(0xFF159447),
                      fontSize: 10.5,
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

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

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
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? theme.dividerColor
                : theme.colorScheme.primary.withOpacity(.25),
            width: isRead ? 1 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark ? (isRead ? .08 : .15) : (isRead ? .035 : .055),
              ),
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
                                color: theme.colorScheme.onSurface,
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
                          color: theme.colorScheme.onSurfaceVariant,
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatNotificationDate(time),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
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
  // NOTIFICATION ICON
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
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(bool isRead) {
    final theme = Theme.of(context);

    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isRead
            ? theme.dividerColor.withOpacity(.35)
            : primary.withOpacity(.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isRead ? theme.colorScheme.onSurfaceVariant : primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isRead ? 'READ' : 'UNREAD',
            style: TextStyle(
              color: isRead ? theme.colorScheme.onSurfaceVariant : primary,
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
  // MORE MENU
  // ============================================================

  Widget _buildMoreButton(Map<String, dynamic> item) {
    final theme = Theme.of(context);

    final isRead = item['isRead'] == true;

    return PopupMenuButton<String>(
      tooltip: 'Notification options',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: 21,
      ),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'read') {
          _markAsRead(item);
        } else if (value == 'delete') {
          _confirmDelete(item);
        }
      },
      itemBuilder: (context) {
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
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    final primary = theme.colorScheme.primary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        // WhatsApp remains visible even
        // when there are no notifications.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: _buildWhatsAppSection(),
        ),

        const SizedBox(height: 15),

        SizedBox(
          height: MediaQuery.of(context).size.height * .48,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(35),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(.09),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: primary,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'All caught up!',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
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
                      color: theme.colorScheme.onSurfaceVariant,
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
    );
  }

  // ============================================================
  // NOTIFICATION TYPE
  // ============================================================

  NotificationStyle _notificationStyle(dynamic type) {
    switch (type?.toString()) {
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
  // DATE PARSER
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

  // ============================================================
  // DATE FORMAT
  // ============================================================

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
  // SNACKBAR
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
// WHATSAPP MESSAGE MODEL
// ================================================================

class WhatsAppMessage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String message;

  const WhatsAppMessage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.message,
  });
}

// ================================================================
// NOTIFICATION STYLE
// ================================================================

class NotificationStyle {
  final IconData icon;
  final Color color;

  const NotificationStyle({required this.icon, required this.color});
}
