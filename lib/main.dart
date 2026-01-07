import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scheduladi/pages/main_navigation.dart';

import 'database/database_helper.dart';
import 'database/database_provider.dart' show DatabaseProvider;
import 'event_manager.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and notifications
  await EventManager().initializeNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Professional Calendar',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      initialRoute: '/home',
      routes: {
        //  '/login': (context) => const LoginPage(),
        // '/signup': (context) => const SignupPage(),
        // '/forgot-password': (context) => const ForgotPasswordPage(),
        /*  '/verify': (context) {
          final email =
              ModalRoute.of(context)!.settings.arguments as String? ?? '';
          return VerifyPage(email: email);
        },*/
        '/home': (context) => const MainNavigation(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

