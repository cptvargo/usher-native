import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/bulletin_service.dart';
import '../services/deployment_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'landing_screen.dart';

/// Root traffic director: shows the landing/auth flow while signed out,
/// and jumps straight to [HomeScreen] whenever Firebase reports a signed-in
/// user — whether that's a fresh login or a session restored on relaunch.
///
/// The service parameters exist so tests can inject fakes for the
/// signed-in ([HomeScreen]) branch; production code should leave them null.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.auth,
    this.authService,
    this.teamService,
    this.bulletinService,
    this.deploymentService,
    this.skipApprovalGateForTesting = false,
  });

  final FirebaseAuth? auth;
  final AuthService? authService;
  final TeamService? teamService;
  final BulletinService? bulletinService;
  final DeploymentService? deploymentService;

  /// TEMPORARY testing switch, forwarded to [HomeScreen]. See its doc
  /// comment.
  final bool skipApprovalGateForTesting;

  @override
  Widget build(BuildContext context) {
    final auth = this.auth ?? FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return Builder(
            builder: (context) => LandingScreen(
              onEnterPortal: (mode) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(
                      initialMode: mode,
                      authService: authService,
                    ),
                  ),
                );
              },
            ),
          );
        }

        return HomeScreen(
          user: user,
          authService: authService,
          teamService: teamService,
          bulletinService: bulletinService,
          deploymentService: deploymentService,
          skipApprovalGateForTesting: skipApprovalGateForTesting,
        );
      },
    );
  }
}
