import 'package:flutter/services.dart';

class LocationTrackingService {
  static const MethodChannel _channel =
      MethodChannel('workforce/location');

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
}