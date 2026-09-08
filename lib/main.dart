import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/location/location_background.dart';

import 'package:workforce/core/services/navigation_service.dart';

@pragma('vm:entry-point')
void locationBackgroundEntryPoint() {
  startLocationBackground();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Workforce',
      theme: ThemeData(useMaterial3: true),
      routerConfig: NavigationService.router,
    );
  }
}
