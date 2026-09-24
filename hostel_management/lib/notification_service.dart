import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ===========================================================================
  // CHANNEL IDS
  // ===========================================================================

  static const String generalChannelId = 'hostel_mess_general';
  static const String mealsChannelId = 'hostel_mess_meals';
  static const String alertsChannelId = 'hostel_mess_alerts';

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // -----------------------------------------------------------------------
      // ANDROID
      // -----------------------------------------------------------------------

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/hostel_notification');

      // -----------------------------------------------------------------------
      // IOS
      // -----------------------------------------------------------------------

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // -----------------------------------------------------------------------
      // SETTINGS
      // -----------------------------------------------------------------------

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // -----------------------------------------------------------------------
      // ANDROID CHANNELS
      // -----------------------------------------------------------------------

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            generalChannelId,
            'HostelMess Notifications',
            description: 'General HostelMess notifications',
            importance: Importance.high,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            mealsChannelId,
            'Meal Notifications',
            description: 'Notifications related to hostel meals',
            importance: Importance.high,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            alertsChannelId,
            'HostelMess Alerts',
            description: 'Important HostelMess alerts',
            importance: Importance.max,
          ),
        );

        // Android 13+
        await androidPlugin.requestNotificationsPermission();
      }

      _initialized = true;

      debugPrint('LocalNotificationService initialized successfully.');
    } catch (e, stackTrace) {
      _initialized = false;

      debugPrint('LocalNotificationService initialization failed: $e');

      debugPrint(stackTrace.toString());
    }
  }

  // ===========================================================================
  // NOTIFICATION TAP
  // ===========================================================================

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ===========================================================================
  // GENERIC NOTIFICATION
  // ===========================================================================

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = generalChannelId,
    String channelName = 'HostelMess Notifications',
    String channelDescription = 'HostelMess notifications',
  }) async {
    try {
      // Initialize if necessary.
      if (!_initialized) {
        await initialize();
      }

      // If initialization still failed, don't crash the application.
      if (!_initialized) {
        debugPrint('Notification skipped: service unavailable.');
        return;
      }

      // -----------------------------------------------------------------------
      // ANDROID DETAILS
      // -----------------------------------------------------------------------

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,

            // IMPORTANT:
            // This MUST match a real resource inside:
            //
            // android/app/src/main/res/drawable/
            //
            icon: '@drawable/hostel_notification',

            autoCancel: true,
            onlyAlertOnce: false,
          );

      // -----------------------------------------------------------------------
      // IOS DETAILS
      // -----------------------------------------------------------------------

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // -----------------------------------------------------------------------
      // FINAL DETAILS
      // -----------------------------------------------------------------------

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(id, title, body, details, payload: payload);
    } catch (e, stackTrace) {
      // Notification failure should NEVER crash HostelMess.
      debugPrint('Show notification failed: $e');

      debugPrint(stackTrace.toString());
    }
  }

  // ===========================================================================
  // MEAL CANCELLED
  // ===========================================================================

  static Future<void> mealCancelled({
    required String meal,
    required String timeSlot,
    String? reason,
  }) async {
    await showNotification(
      id: 1001,
      title: '❌ Meal Cancelled',
      body: reason == null || reason.trim().isEmpty
          ? '$meal meal for $timeSlot has been cancelled.'
          : '$meal meal for $timeSlot has been cancelled. $reason',
      channelId: mealsChannelId,
      channelName: 'Meal Notifications',
      channelDescription: 'Notifications related to hostel meals',
    );
  }

  // ===========================================================================
  // MEAL SERVED
  // ===========================================================================

  static Future<void> mealServed({
    required String meal,
    required String timeSlot,
  }) async {
    await showNotification(
      id: 1002,
      title: '🍽️ Meal Served',
      body: '$meal meal for $timeSlot is now being served.',
      channelId: mealsChannelId,
      channelName: 'Meal Notifications',
      channelDescription: 'Notifications related to hostel meals',
    );
  }

  // ===========================================================================
  // TAKE YOUR MEAL
  // ===========================================================================

  static Future<void> takeYourMeal({
    required String meal,
    required String timeSlot,
    String? mealDate,
  }) async {
    final String dateText = mealDate == null || mealDate.trim().isEmpty
        ? ''
        : ' ($mealDate)';

    await showNotification(
      id: 1003,
      title: '🍽️ Take Your Meal',
      body:
          'Your $meal meal for $timeSlot$dateText has been served. Please collect your meal.',
      channelId: mealsChannelId,
      channelName: 'Meal Notifications',
      channelDescription: 'Notifications related to hostel meals',
    );
  }

  // ===========================================================================
  // MEAL BALANCE WARNING
  // ===========================================================================

  static Future<void> mealBalanceWarning({required int remainingMeals}) async {
    await showNotification(
      id: 1004,
      title: '⚠️ Meal Balance Low',
      body:
          'You have only $remainingMeals meal${remainingMeals == 1 ? '' : 's'} remaining in your current plan.',
      channelId: alertsChannelId,
      channelName: 'HostelMess Alerts',
      channelDescription: 'Important HostelMess alerts',
    );
  }

  // ===========================================================================
  // NEW CYCLE
  // ===========================================================================

  static Future<void> newCycleActivated({String? cycleName}) async {
    await showNotification(
      id: 1005,
      title: '🔄 New Meal Cycle',
      body: cycleName == null || cycleName.trim().isEmpty
          ? 'A new meal cycle has been activated.'
          : 'The new meal cycle "$cycleName" has been activated.',
      channelId: generalChannelId,
      channelName: 'HostelMess Notifications',
      channelDescription: 'General HostelMess notifications',
    );
  }

  // ===========================================================================
  // MEETING ARRANGED
  // ===========================================================================

  static Future<void> meetingArranged({required String message}) async {
    await showNotification(
      id: 1006,
      title: '📅 Meeting Arranged',
      body: message,
      channelId: generalChannelId,
      channelName: 'HostelMess Notifications',
      channelDescription: 'General HostelMess notifications',
    );
  }

  // ===========================================================================
  // GATE CLOSED
  // ===========================================================================

  static Future<void> gateClosed({String? message}) async {
    await showNotification(
      id: 1007,
      title: '🚪 Gate Closed',
      body: message == null || message.trim().isEmpty
          ? 'The hostel gate has been closed.'
          : message,
      channelId: alertsChannelId,
      channelName: 'HostelMess Alerts',
      channelDescription: 'Important HostelMess alerts',
    );
  }

  // ===========================================================================
  // CANCEL ONE NOTIFICATION
  // ===========================================================================

  static Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      debugPrint('Cancel notification failed: $e');
    }
  }

  // ===========================================================================
  // CANCEL ALL
  // ===========================================================================

  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Cancel all notifications failed: $e');
    }
  }
}
