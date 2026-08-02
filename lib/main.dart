import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _ScaffoldStatusScreen(),
    );
  }
}

class _ScaffoldStatusScreen extends StatelessWidget {
  const _ScaffoldStatusScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gate Guardians')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Flutter project scaffolded.\nFirebase connected to church-usher-app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
