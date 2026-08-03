import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/attendance_log.dart';
import '../models/bulletin_block.dart';
import '../models/deployment.dart';
import '../models/roster_member.dart';
import '../models/team_profile.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/bulletin_parser.dart';
import '../services/bulletin_service.dart';
import '../services/deployment_service.dart';
import '../services/roster_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import '../widgets/bulletin_blocks.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glow_blob.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    this.authService,
    this.teamService,
    this.bulletinService,
    this.deploymentService,
    this.rosterService,
    this.attendanceService,
    this.skipApprovalGateForTesting = false,
  });

  final User user;
  final AuthService? authService;
  final TeamService? teamService;
  final BulletinService? bulletinService;
  final DeploymentService? deploymentService;
  final RosterService? rosterService;
  final AttendanceService? attendanceService;

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
          attendanceService: widget.attendanceService,
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
    this.attendanceService,
  });

  final User user;
  final TeamProfile profile;
  final AuthService authService;
  final BulletinService? bulletinService;
  final DeploymentService? deploymentService;
  final RosterService? rosterService;
  final AttendanceService? attendanceService;

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
      case 'Attendance':
        return _AttendanceTab(
          key: const ValueKey('attendance'),
          profile: widget.profile,
          service: widget.attendanceService ?? AttendanceService(),
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

/// The current head usher's byline shown on the bulletin card. Not stored
/// in Firestore (the `team` collection has no single "head usher" concept
/// beyond the Admin role) — edit this if leadership changes.
const kHeadUsherName = 'Louis Richardson';

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
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -110,
                  child: GlowBlob(
                    size: 300,
                    colors: [
                      AppColors.amber100.withValues(alpha: 0.5),
                      AppColors.amber600.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            FadeSlideIn(
              child: Text(
                'Welcome back, ${profile.name.split(' ').first}.',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _BulletinCard(service: bulletinService ?? BulletinService()),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: _UpcomingDeploymentsCard(
                service: deploymentService ?? DeploymentService(),
                usherId: profile.id,
              ),
            ),
          ],
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
  List<_EditItem>? _editItems;
  String? _latestText;

  @override
  void dispose() {
    _disposeEditItems();
    super.dispose();
  }

  void _disposeEditItems() {
    for (final item in _editItems ?? const <_EditItem>[]) {
      item.controller.dispose();
    }
  }

  void _startEditing() {
    final blocks = parseBulletin(_latestText ?? '');
    final items = [
      for (final b in blocks)
        switch (b) {
          BulletinHeader(:final text) => _EditLine(_LineKind.header, text),
          BulletinParagraph(:final text) => _EditLine(_LineKind.paragraph, text),
          BulletinClosing(:final text) => _EditLine(_LineKind.closing, text),
          BulletinTeamUpdates(:final entries) => _EditTeam(entries),
        },
    ];
    if (items.isEmpty) items.add(_EditLine(_LineKind.header, ''));
    setState(() {
      _editItems = items;
      _editing = true;
    });
  }

  Future<void> _save() async {
    final items = _editItems;
    if (items == null) return;
    final raw = items
        .map((item) => item.controller.text.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');

    setState(() => _saving = true);
    await widget.service.save(raw);
    if (!mounted) return;
    _disposeEditItems();
    setState(() {
      _saving = false;
      _editing = false;
      _editItems = null;
    });
  }

  void _cancelEditing() {
    _disposeEditItems();
    setState(() {
      _editing = false;
      _editItems = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.slate900, const Color(0xFF78350F)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber800.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          StreamBuilder<String>(
            stream: widget.service.watch(),
            builder: (context, snapshot) {
              final text = snapshot.data;
              if (text != null) _latestText = text;

              return Padding(
                padding: const EdgeInsets.only(right: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: kHeadUsherName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: '  ·  HEAD USHER',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.amber100.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                    const SizedBox(height: 18),
                    if (text == null)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else if (_editing)
                      _BulletinEditor(
                        items: _editItems!,
                        onRemove: (i) => setState(() => _editItems!.removeAt(i)),
                        onAddLine: () => setState(
                          () => _editItems!.add(_EditLine(_LineKind.paragraph, '')),
                        ),
                        onCancel: _cancelEditing,
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final block in parseBulletin(text))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BulletinBlockView(block: block),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              key: const ValueKey('bulletinEditButton'),
              onTap: _saving ? null : () => _editing ? _save() : _startEditing(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(
                        _editing ? Icons.check_rounded : Icons.edit_rounded,
                        size: 14,
                        color: _editing ? const Color(0xFF34D399) : Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _LineKind { header, paragraph, closing }

sealed class _EditItem {
  TextEditingController get controller;
}

class _EditLine extends _EditItem {
  _EditLine(this.kind, String text) : controller = TextEditingController(text: text);
  final _LineKind kind;
  @override
  final TextEditingController controller;
}

class _EditTeam extends _EditItem {
  _EditTeam(List<TeamUpdateEntry> entries)
      : controller =
            TextEditingController(text: entries.map((e) => e.toLine()).join('\n'));
  @override
  final TextEditingController controller;
}

/// Inline editor that mirrors the read view's section layout — the author
/// types directly into the same Header/Paragraph/Team Updates blocks
/// instead of one undifferentiated text box.
class _BulletinEditor extends StatelessWidget {
  const _BulletinEditor({
    required this.items,
    required this.onRemove,
    required this.onAddLine,
    required this.onCancel,
  });

  final List<_EditItem> items;
  final void Function(int index) onRemove;
  final VoidCallback onAddLine;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: switch (items[i]) {
              _EditLine line => _EditLineField(line: line, onRemove: () => onRemove(i)),
              _EditTeam team => _EditTeamField(team: team),
            },
          ),
        Row(
          children: [
            GestureDetector(
              onTap: onAddLine,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.amber200),
                  const SizedBox(width: 4),
                  Text(
                    'ADD LINE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.amber200,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: onCancel,
              child: Text(
                'CANCEL',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditLineField extends StatelessWidget {
  const _EditLineField({required this.line, required this.onRemove});
  final _EditLine line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final style = switch (line.kind) {
      _LineKind.header => GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppColors.amber200,
        ),
      _LineKind.paragraph ||
      _LineKind.closing =>
        GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.92),
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: line.controller,
            maxLines: null,
            style: style,
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        GestureDetector(
          onTap: onRemove,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Icon(Icons.close_rounded, size: 14, color: Colors.white.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }
}

class _EditTeamField extends StatelessWidget {
  const _EditTeamField({required this.team});
  final _EditTeam team;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: AppColors.amber700, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.groups_rounded, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'TEAM UPDATES',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.amber200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: team.controller,
            maxLines: null,
            style: GoogleFonts.inter(fontSize: 13, height: 1.8, color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'One name per line — add a role like "Robert - Lead Usher"',
              hintStyle: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.32),
              ),
            ),
          ),
        ],
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppColors.amber800,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MY UPCOMING ASSIGNMENTS',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.slate400,
                ),
              ),
            ],
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

const _serviceInstances = [
  'Sunday Morning',
  'Sunday Evening',
  'Wednesday Midweek',
  'Special Revival / Event',
];

/// Tap-to-count headcount input: no keyboard, just + and − so an usher can
/// tally people at the door and correct a miscount on the spot.
class _TallyCounter extends StatelessWidget {
  const _TallyCounter({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TallyButton(
            key: const ValueKey('tallyMinus'),
            icon: Icons.remove_rounded,
            enabled: value > 0,
            onTap: () => onChanged(value - 1),
          ),
          Column(
            children: [
              Text(
                '$value',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: AppColors.slate800,
                ),
              ),
              Text(
                'HEADCOUNT',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
          _TallyButton(
            key: const ValueKey('tallyPlus'),
            icon: Icons.add_rounded,
            enabled: true,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _TallyButton extends StatelessWidget {
  const _TallyButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.amber700 : AppColors.amber700.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({super.key, required this.profile, required this.service});

  final TeamProfile profile;
  final AttendanceService service;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  int _headcount = 0;
  final _notesCtrl = TextEditingController();
  String _serviceInstance = _serviceInstances.first;
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await widget.service.addLog(
      headcount: _headcount,
      serviceType: _serviceInstance,
      notes: _notesCtrl.text.trim(),
      submittedBy: widget.profile.name,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _headcount = 0;
      _notesCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Icon(Icons.fact_check_rounded, color: AppColors.amber700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'New Attendance Log',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _serviceInstance,
                decoration: _fieldDecoration(),
                items: [
                  for (final s in _serviceInstances)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _serviceInstance = v ?? _serviceInstance),
              ),
              const SizedBox(height: 12),
              _TallyCounter(
                value: _headcount,
                onChanged: (v) => setState(() => _headcount = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: _fieldDecoration(hint: 'Service notes (optional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _submitting ? 'Publishing…' : 'Publish Service Log',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Historical Headcounts',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: AppColors.slate800,
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<AttendanceLog>>(
          stream: widget.service.watchLogs(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorNotice(error: snapshot.error!);
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final logs = snapshot.data!;
            if (logs.isEmpty) {
              return Text(
                'No attendance logs yet.',
                style: GoogleFonts.inter(color: AppColors.slate400),
              );
            }
            return Column(
              children: [
                for (final log in logs)
                  _AttendanceLogCard(
                    log: log,
                    canEdit: widget.profile.isLead,
                    service: widget.service,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}

class _AttendanceLogCard extends StatefulWidget {
  const _AttendanceLogCard({
    required this.log,
    required this.canEdit,
    required this.service,
  });

  final AttendanceLog log;
  final bool canEdit;
  final AttendanceService service;

  @override
  State<_AttendanceLogCard> createState() => _AttendanceLogCardState();
}

class _AttendanceLogCardState extends State<_AttendanceLogCard> {
  bool _editing = false;
  late int _headcount = widget.log.headcount;
  late final TextEditingController _notesCtrl =
      TextEditingController(text: widget.log.notes ?? '');

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.service.updateLog(
      widget.log.id,
      headcount: _headcount,
      notes: _notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _editing = false);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete this log?'),
        content: const Text('This attendance entry will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.service.deleteLog(widget.log.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.amber50),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _editing ? _buildEditForm() : _buildReadView(log),
    );
  }

  Widget _buildReadView(AttendanceLog log) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber100.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.serviceType,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.amber800,
                      ),
                    ),
                  ),
                  if (log.createdAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(log.createdAt!),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.canEdit) ...[
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 15),
                color: AppColors.slate400,
                onPressed: () => setState(() => _editing = true),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                color: AppColors.slate400,
                onPressed: _confirmDelete,
              ),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${log.headcount}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: AppColors.slate800,
                  ),
                ),
                Text(
                  'SAINTS COUNTED',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (log.notes != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              log.notes!,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.5,
                color: AppColors.slate500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'LOGGED BY: ${log.submittedBy}'.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.slate400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TallyCounter(
          value: _headcount,
          onChanged: (v) => setState(() => _headcount = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: _fieldDecoration(hint: 'Notes'),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
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
