import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/location/location_background.dart';
import 'package:workforce/core/push/push_bridge.dart';
import 'package:workforce/core/push/push_notification_service.dart';
import 'package:workforce/core/services/navigation_service.dart';
import 'package:workforce/core/styles/app_theme.dart';
import 'package:workforce/features/call/presentation/call_screen.dart';

@pragma('vm:entry-point')
void locationBackgroundEntryPoint() {
  startLocationBackground();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocalization.load();
  // Before runApp: the background handler has to be registered first, and a
  // notification tap that launched the app is read here.
  await PushNotificationService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'WorkForce',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: NavigationService.router,
      // A call rings, and stays on screen, over whichever page is open.
      builder: (context, child) => PushBridge(
        child: CallLayer(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
