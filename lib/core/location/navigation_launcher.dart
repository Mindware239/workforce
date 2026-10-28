import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches GPS Navigation directly in Google Maps for field executives to client destinations.
/// Opens Google Maps with client pin, live traffic, ETA, and driving directions.
class NavigationLauncher {
  NavigationLauncher._();

  /// Opens the target client coordinates or address directly in Google Maps
  /// with live traffic, ETA, and driving route.
  static Future<bool> startTurnByTurnNavigation({
    required double destinationLat,
    required double destinationLng,
    String? destinationLabel,
    String? destinationAddress,
  }) async {
    try {
      final hasCoords = (destinationLat != 0.0 && destinationLng != 0.0) &&
          destinationLat >= -90.0 &&
          destinationLat <= 90.0 &&
          destinationLng >= -180.0 &&
          destinationLng <= 180.0;

      final label = destinationLabel ?? destinationAddress ?? 'Client';

      final destParam = hasCoords
          ? '$destinationLat,$destinationLng'
          : (destinationAddress != null && destinationAddress.trim().isNotEmpty
              ? Uri.encodeComponent(destinationAddress.trim())
              : Uri.encodeComponent(label));

      // 1. iOS: If Google Maps app is installed on iOS, use comgooglemaps directions
      if (!kIsWeb && Platform.isIOS) {
        final googleMapsIos = Uri.parse(
          'comgooglemaps://?daddr=$destParam&directionsmode=driving',
        );
        if (await canLaunchUrl(googleMapsIos)) {
          final ok = await launchUrl(googleMapsIos, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }

        // iOS Fallback: Apple Maps with driving directions
        final appleMapsUri = Uri.parse('http://maps.apple.com/?daddr=$destParam&dirflg=d');
        if (await canLaunchUrl(appleMapsUri)) {
          final ok = await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
      }

      // 2. Android & Universal: Official Google Maps Directions API URL
      // Sets destination to the client location with travelmode=driving.
      // Displays:
      // - Customer destination pin
      // - Real-time traffic colors (green/orange/red)
      // - Live ETA and distance
      // - Blue 'Start' button for turn-by-turn navigation
      // Bypasses third-party apps like Porter (which cannot hijack google.com links).
      final googleMapsDirectionsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destParam&travelmode=driving',
      );

      if (await canLaunchUrl(googleMapsDirectionsUri)) {
        final ok = await launchUrl(
          googleMapsDirectionsUri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return true;
      }

      // 3. Fallback: Classic Google Maps Directions URL
      final classicDirectionsUri = Uri.parse(
        'https://maps.google.com/maps?daddr=$destParam',
      );
      if (await canLaunchUrl(classicDirectionsUri)) {
        final ok = await launchUrl(
          classicDirectionsUri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return true;
      }

      // 4. Fallback: Search / Pin URL
      final googleMapsSearchUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$destParam',
      );
      if (await canLaunchUrl(googleMapsSearchUri)) {
        return await launchUrl(
          googleMapsSearchUri,
          mode: LaunchMode.externalApplication,
        );
      }

      return false;
    } catch (e) {
      debugPrint('Navigation launch failed: $e');
      return false;
    }
  }
}
