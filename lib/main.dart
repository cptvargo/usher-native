import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GateGuardiansApp());
}

class GateGuardiansApp extends StatelessWidget {
  const GateGuardiansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gate Guardians',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.amber700),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      // TODO(testing): set back to false (or remove) once manual testing
      // of the dashboard is done — this skips the real approval gate.
      home: const AuthGate(skipApprovalGateForTesting: true),
    );
  }
}
