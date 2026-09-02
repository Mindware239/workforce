import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:workforce/core/services/navigation_service.dart';

class OnboardingBloc extends Cubit<int> {
  OnboardingBloc() : super(0);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingBloc(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Workforce',
        theme: ThemeData(
          useMaterial3: true,
          
        ),
        routerConfig: NavigationService.router,
      ),
    );
  }
}