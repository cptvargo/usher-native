import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/deployment.dart';
import '../models/roster_member.dart';
import '../models/team_profile.dart';
import '../services/auth_service.dart';
import '../services/bulletin_service.dart';
import '../services/deployment_service.dart';
import '../services/roster_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    this.authService,
    this.teamService,
    this.bulletinService,
    this.deploymentService,
    this.rosterService,
    this.skipApprovalGateForTesting = false,
  });

  final User user;
  final AuthService? authService;
  final TeamService? teamService;
  final BulletinService? bulletinService;
  final DeploymentService? deploymentService;
  final RosterService? rosterService;

  /// TEMPORARY testing switch — skips the "Pending Approval" gate so the
  /// dashboard can be reached without an admin approving the account first.
  /// Flip the call site back to false (or remove the argument) once manual
  /// testing is done; the real gating logic/tests are unaffected.
  final bool skipApprovalGateForTesting;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final TeamService _teamService = widget.teamService ?? TeamService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TeamProfile?>(
      stream: _teamService.watchProfile(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenteredStatus(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        if (profile == null) {
          return _CenteredStatus(
            child: Text(
              'Setting up your profile…',
              style: GoogleFonts.inter(color: AppColors.slate500),
            ),
          );
        }

        if (profile.denied) {
          return _GateStatusScreen(
            icon: Icons.cancel_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Registration Denied',
            message:
                'Your registration was not approved. Please contact a lead usher for assistance.',
            onSignOut: () => _authService.signOut(),
          );
        }

        if (!profile.approved && !widget.skipApprovalGateForTesting) {
          return _GateStatusScreen(
            icon: Icons.hourglass_top_rounded,
            iconColor: AppColors.amber700,
            title: 'Pending Approval',
            message:
                "Your registration is awaiting approval from a lead usher. You'll gain access once approved.",
            onSignOut: () => _authService.signOut(),
            spinning: true,
          );
        }

        return _Dashboard(
          user: widget.user,
          profile: profile,
          authService: _authService,
          bulletinService: widget.bulletinService,
          deploymentService: widget.deploymentService,
          rosterService: widget.rosterService,
        );
      },
    );
  }
}

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: child),
    );
  }
}

class _GateStatusScreen extends StatelessWidget {
  const _GateStatusScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.onSignOut,
    this.spinning = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback onSignOut;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (spinning)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: iconColor,
                      ),
                    )
                  else
                    Icon(icon, size: 40, color: iconColor),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: onSignOut,
                    child: Text(
                      'SIGN OUT',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.amber700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _navDestinations = [
  _NavDestination(Icons.bolt_rounded, 'Dashboard'),
  _NavDestination(Icons.forum_rounded, 'Bulletin'),
  _NavDestination(Icons.calendar_month_rounded, 'Calendar'),
  _NavDestination(Icons.groups_rounded, 'Roster'),
  _NavDestination(Icons.fact_check_rounded, 'Attendance'),
];

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.user,
    required this.profile,
    required this.authService,
    this.bulletinService,
    this.deploymentService,
    this.rosterService,
  });

  final User user;
  final TeamProfile profile;
  final AuthService authService;
  final BulletinService? bulletinService;
  final DeploymentService? deploymentService;
  final RosterService? rosterService;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  int _tabIndex = 0;

  List<_NavDestination> get _destinations => [
        ..._navDestinations,
        if (widget.profile.isAdmin)
          const _NavDestination(Icons.shield_rounded, 'Admin'),
      ];

  void _openProfileSheet() {
    final user = widget.user;
    final showEmail =
        user.email != null && !user.email!.endsWith('@usherapp.internal');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AUTHENTICATED ID',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.amber600.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.profile.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: AppColors.slate800,
              ),
            ),
            if (showEmail) ...[
              const SizedBox(height: 4),
              Text(
                user.email!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.authService.signOut();
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text(
                  'SIGN OUT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab() {
    final destination = _destinations[_tabIndex];
    switch (destination.label) {
      case 'Dashboard':
        return _DashboardTab(
          key: const ValueKey('dashboard'),
          profile: widget.profile,
          bulletinService: widget.bulletinService,
          deploymentService: widget.deploymentService,
        );
      case 'Roster':
        return _RosterTab(
          key: const ValueKey('roster'),
          profile: widget.profile,
          service: widget.rosterService ?? RosterService(),
        );
      case 'Admin':
        return _AdminTab(
          key: const ValueKey('admin'),
          service: widget.rosterService ?? RosterService(),
        );
      default:
        return _ComingSoonTab(key: ValueKey(_tabIndex), destination: destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              onBellTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications — coming soon.')),
              ),
              onAvatarTap: _openProfileSheet,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildTab(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        destinations: _destinations,
        selectedIndex: _tabIndex,
        onSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = i);
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBellTap, required this.onAvatarTap});

  final VoidCallback onBellTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sunday Connect',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate800,
                  ),
                ),
                Text(
                  'SERVANT LEADERSHIP PORTAL',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.amber600.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _CircleIconButton(icon: Icons.notifications_none_rounded, onTap: onBellTap),
          const SizedBox(width: 10),
          GestureDetector(
            key: const ValueKey('avatarButton'),
            onTap: onAvatarTap,
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.amber100),
              ),
              child: ClipOval(
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.amber100),
        ),
        child: Icon(icon, size: 18, color: AppColors.slate500),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    super.key,
    required this.profile,
    this.bulletinService,
    this.deploymentService,
  });

  final TeamProfile profile;
  final BulletinService? bulletinService;
  final DeploymentService? deploymentService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Welcome back, ${profile.name.split(' ').first}.',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 18),
        _BulletinCard(service: bulletinService ?? BulletinService()),
        const SizedBox(height: 18),
        _UpcomingDeploymentsCard(
          service: deploymentService ?? DeploymentService(),
          usherId: profile.id,
        ),
      ],
    );
  }
}

class _BulletinCard extends StatefulWidget {
  const _BulletinCard({required this.service});
  final BulletinService service;

  @override
  State<_BulletinCard> createState() => _BulletinCardState();
}

class _BulletinCardState extends State<_BulletinCard> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.service.save(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.amber50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.amber100.withValues(alpha: 0.6)),
      ),
      child: StreamBuilder<String>(
        stream: widget.service.watch(),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (!_editing && text != null) _controller.text = text;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SERVICE BULLETIN',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.amber700.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  if (text == null)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_editing)
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Text(
                        _saving ? 'SAVING…' : 'SAVE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _editing = true),
                      child: Text(
                        'EDIT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.amber700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_editing)
                TextField(
                  controller: _controller,
                  maxLines: null,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppColors.slate800,
                  ),
                  decoration: const InputDecoration(border: InputBorder.none),
                )
              else
                Text(
                  text ?? '',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: AppColors.slate800,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingDeploymentsCard extends StatelessWidget {
  const _UpcomingDeploymentsCard({required this.service, required this.usherId});

  final DeploymentService service;
  final String usherId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.amber50),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MY UPCOMING ASSIGNMENTS',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.slate400,
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Deployment>>(
            stream: service.watchUpcoming(usherId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final deployments = snapshot.data!;
              if (deployments.isEmpty) {
                return Text(
                  'No upcoming assignments yet. Check back once the next roster is posted.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.slate400,
                  ),
                );
              }
              return Column(
                children: [
                  for (final d in deployments) _DeploymentRow(deployment: d),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeploymentRow extends StatelessWidget {
  const _DeploymentRow({required this.deployment});
  final Deployment deployment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${deployment.date} · ${deployment.label}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Station: ${deployment.station ?? 'Unassigned'} · Role: ${deployment.role ?? 'Usher'}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          if (deployment.requestingCover)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber600.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COVER REQUESTED',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.amber800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({super.key, required this.destination});
  final _NavDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.amber50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(destination.icon, size: 28, color: AppColors.amber800),
            ),
            const SizedBox(height: 18),
            Text(
              destination.label,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: AppColors.slate800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coming soon.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }
}

const _roleOptions = ['Usher', 'Lead', 'Admin'];

Color _roleColor(String role) {
  switch (role) {
    case 'Admin':
      return const Color(0xFF10B981);
    case 'Lead':
      return const Color(0xFF3B82F6);
    default:
      return AppColors.amber700;
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load data: $error',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterTab extends StatelessWidget {
  const _RosterTab({super.key, required this.profile, required this.service});

  final TeamProfile profile;
  final RosterService service;

  Future<void> _openUsherForm(
    BuildContext context, {
    RosterMember? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    final phoneCtrl = TextEditingController(text: existing?.phone);
    var role = existing?.role ?? 'Usher';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            existing == null ? 'Add New Personnel' : 'Edit Personnel',
            style: GoogleFonts.playfairDisplay(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: AppColors.slate800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AuthLikeField(controller: nameCtrl, hint: 'Full Name'),
              const SizedBox(height: 12),
              _AuthLikeField(controller: phoneCtrl, hint: 'Phone Number'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.amber50.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _roleOptions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => role = v ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.amber700),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;
                if (existing == null) {
                  await service.addUsher(name: name, phone: phone, role: role);
                } else {
                  await service.updateUsher(existing.id,
                      name: name, phone: phone, role: role);
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(existing == null ? 'Save to Database' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RosterMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Remove from roster?'),
        content: Text(
          'Remove ${member.name} from the roster permanently?',
          style: GoogleFonts.inter(color: AppColors.slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteUsher(member.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RosterMember>>(
      stream: service.watchActiveRoster(),
      builder: (context, snapshot) {
        final roster = snapshot.data ?? const <RosterMember>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usher Database',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                        ),
                      ),
                      Text(
                        '${roster.length} Active Personnel',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.amber600.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (profile.isLead)
                  FilledButton.icon(
                    onPressed: () => _openUsherForm(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.slate900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Name'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _ErrorNotice(error: snapshot.error!)
            else if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (roster.isEmpty)
              Text(
                'No active personnel yet.',
                style: GoogleFonts.inter(color: AppColors.slate400),
              )
            else
              for (final member in roster)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.amber50),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.amber700, AppColors.amber800],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.slate800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _roleColor(member.role)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    member.role,
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: _roleColor(member.role),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  member.phone ?? 'No Phone',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (profile.isLead) ...[
                        IconButton(
                          onPressed: () =>
                              _openUsherForm(context, existing: member),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          color: AppColors.slate400,
                        ),
                        IconButton(
                          onPressed: () => _confirmDelete(context, member),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          color: AppColors.slate400,
                        ),
                      ],
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _AuthLikeField extends StatelessWidget {
  const _AuthLikeField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.amber50.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _AdminTab extends StatelessWidget {
  const _AdminTab({super.key, required this.service});
  final RosterService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RosterMember>>(
      stream: service.watchPendingRegistrations(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? const <RosterMember>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Admin Panel',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: AppColors.slate800,
              ),
            ),
            Text(
              'REGISTRATION APPROVALS',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.amber600.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _ErrorNotice(error: snapshot.error!)
            else if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (pending.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.amber50),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 32, color: Color(0xFF10B981)),
                    const SizedBox(height: 10),
                    Text(
                      "No pending registrations. You're all caught up.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontStyle: FontStyle.italic,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final member in pending)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.amber50),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.slate800,
                              ),
                            ),
                            Text(
                              member.phone ?? member.email ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.slate400,
                              ),
                            ),
                            if (member.createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Registered: ${DateFormat.yMMMd().format(member.createdAt!)}',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amber600.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => service.approve(member.id),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          foregroundColor: const Color(0xFF10B981),
                        ),
                        child: const Text('APPROVE'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => service.deny(member.id),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          foregroundColor: const Color(0xFFEF4444),
                        ),
                        child: const Text('DENY'),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavDestination> destinations;
  final int selectedIndex;
  final void Function(int) onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.amber100.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate900.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavIcon(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.amber700 : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            destination.icon,
            size: 19,
            color: selected ? Colors.white : AppColors.slate400,
          ),
        ),
      ),
    );
  }
}
