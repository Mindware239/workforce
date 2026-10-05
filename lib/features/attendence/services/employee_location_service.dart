import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationTrackingService {
  static const MethodChannel _channel =
      MethodChannel('workforce/location');

  /// Starts the native foreground tracking service.
  ///
  /// Returns false when location permission is missing.
  static Future<bool> start() async {
    final result = await _channel.invokeMethod<bool>(
      'startTracking',
    );

    return result == true;
  }

  static Future<bool> stop() async {
    final result = await _channel.invokeMethod<bool>(
      'stopTracking',
    );

    return result == true;
  }

  /// Requests the permissions needed for tracking to keep running
  /// after the app is closed or the phone restarts.
  ///
  /// Google Play requires a prominent in-app disclosure to be shown
  /// before asking for background ("Allow all the time") location.
  /// Tracking still runs while checked in if the user declines, but
  /// it won't resume automatically after a reboot.
  static Future<void> requestAlwaysPermission(
    BuildContext context,
    String Function(String key) tr,
  ) async {
    if (!Platform.isAndroid) return;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (!await Permission.locationWhenInUse.isGranted) return;

    if (await Permission.locationAlways.isGranted) return;

    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.location_on_outlined),
          title: Text(tr('locationDisclosure.title')),
          content: Text(tr('locationDisclosure.message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr('locationDisclosure.notNow')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr('locationDisclosure.allow')),
            ),
          ],
        );
      },
    );

    if (accepted == true) {
      // On Android 11+ this opens the system settings page where the
      // user picks "Allow all the time".
      await Permission.locationAlways.request();
    }
  }
}
