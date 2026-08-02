import 'package:flutter/material.dart';

// TODO: once `flutterfire configure` has been run against the
// church-usher-app Firebase project, initialize Firebase here:
//
//   import 'package:firebase_core/firebase_core.dart';
//   import 'firebase_options.dart';
//   ...
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

void main() {
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
            'Flutter project scaffolded.\nRun flutterfire configure to connect Firebase.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
