import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Windows initialization settings
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'EasyRealtorsPro',
      appUserModelId: '5347a83d-e300-4573-b6d3-2410a568a045',
      guid: '5347a83d-e300-4573-b6d3-2410a568a045',
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      windows: initializationSettingsWindows,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }

    _initialized = true;
    debugPrint('Notification service initialized');
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap if needed
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required TimeOfDay scheduledTime,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Combine date and time
    final scheduledDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    // If the scheduled time is in the past, schedule for next day
    if (scheduledDateTime.isBefore(DateTime.now())) {
      debugPrint('Scheduled time is in the past, skipping notification');
      return;
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDateTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminders',
            channelDescription: 'Manual reminder notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
              htmlFormatContent: true,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('Reminder scheduled successfully for $scheduledDateTime');
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
      rethrow;
    }
  }

  Future<void> cancelReminder(int id) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('Reminder with id $id cancelled');
    } catch (e) {
      debugPrint('Error cancelling reminder: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('All reminders cancelled');
    } catch (e) {
      debugPrint('Error cancelling all reminders: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error getting pending reminders: $e');
      return [];
    }
  }

  Future<bool> hasPermission() async {
    if (!_initialized) {
      await initialize();
    }

    if (Platform.isIOS) {
      final iOSPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      // For iOS, we'll assume permissions are granted if initialization succeeded
      return true;
    } else if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }

    return false;
  }

  Future<void> requestPermission() async {
    if (!_initialized) {
      await initialize();
    }

    if (Platform.isIOS) {
      final iOSPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iOSPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'immediate_channel',
            'Immediate Notifications',
            channelDescription: 'Immediate notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing immediate notification: $e');
    }
  }
}
