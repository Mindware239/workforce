import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A fix at or below this accuracy is a real GPS pin-point.
const double kPreciseAccuracyMeters = 25;

/// Returns the most accurate position the device can give within [timeout].
///
/// `Geolocator.getCurrentPosition` returns the first fix Android has, which
/// indoors is often a cell-tower / Wi-Fi estimate 100-400 m away from the
/// employee. Listening for a few seconds lets the GPS lock on: this returns as
/// soon as a fix is within [kPreciseAccuracyMeters], otherwise the best fix
/// seen when [timeout] runs out.
Future<Position> getPrecisePosition({
  Duration timeout = const Duration(seconds: 15),
}) async {
  Position? best;
  final completer = Completer<Position>();

  final subscription = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    ),
  ).listen(
    (position) {
      debugPrint('📍 Fix: accuracy=${position.accuracy.toStringAsFixed(1)} m');

      if (best == null || position.accuracy < best!.accuracy) {
        best = position;
      }

      if (position.accuracy <= kPreciseAccuracyMeters &&
          !completer.isCompleted) {
        completer.complete(position);
      }
    },
    onError: (Object error) {
      if (completer.isCompleted) return;

      if (best != null) {
        completer.complete(best!);
      } else {
        completer.completeError(error);
      }
    },
  );

  final timer = Timer(timeout, () {
    if (completer.isCompleted) return;

    if (best != null) {
      completer.complete(best!);
    } else {
      // No fix from the stream at all; fall back to a one-shot request.
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).then(
        (position) {
          if (!completer.isCompleted) completer.complete(position);
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
      );
    }
  });

  try {
    return await completer.future;
  } finally {
    timer.cancel();
    await subscription.cancel();
  }
}
