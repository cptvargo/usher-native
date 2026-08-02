import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/fade_slide_in.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.onEnterPortal});

  /// mode is 'login' or 'register'.
  final void Function(String mode) onEnterPortal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -180,
                    left: -140,
                    child: _GlowBlob(
                      size: 380,
                      colors: [AppColors.amber100.withValues(alpha: 0.55), AppColors.amber600.withValues(alpha: 0.0)],
                    ),
                  ),
                  Positioned(
                    bottom: -160,
                    right: -140,
                    child: _GlowBlob(
                      size: 340,
                      colors: [AppColors.amber100.withValues(alpha: 0.45), AppColors.amber600.withValues(alpha: 0.0)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Hero()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 260),
                          child: _CTARow(onEnterPortal: onEnterPortal),
                        ),
                        const SizedBox(height: 56),
                        _FeatureGrid(),
                        const SizedBox(height: 48),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 900),
                          child: Text(
                            '© ${DateTime.now().year} Guardians of the Gate · Servant Leadership Registry',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FadeSlideIn(
          duration: const Duration(milliseconds: 700),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/sanctuary_gates.png',
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          AppColors.background,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -34),
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: Column(
              children: [
                _LogoBadge(),
                const SizedBox(height: 18),
                Text(
                  'GUARDIANS OF THE GATE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.2,
                    color: AppColors.amber800.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 38,
                        height: 1.15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate800,
                      ),
                      children: [
                        const TextSpan(text: 'Servant leadership '),
                        TextSpan(
                          text: 'begins at the gate.',
                          style: TextStyle(color: AppColors.amber700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'The secure scheduling, attendance registry, and communications hub for the Sanctuary Safety and Usher Ministry.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.amber100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber800.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
      ),
    );
  }
}

class _CTARow extends StatelessWidget {
  const _CTARow({required this.onEnterPortal});

  final void Function(String mode) onEnterPortal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CTAButton(
          label: 'Enter Portal',
          filled: true,
          onTap: () => onEnterPortal('login'),
        ),
        const SizedBox(height: 12),
        _CTAButton(
          label: 'Request Access',
          filled: false,
          onTap: () => onEnterPortal('register'),
        ),
      ],
    );
  }
}

class _CTAButton extends StatefulWidget {
  const _CTAButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? AppColors.amber700 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: widget.filled
                ? null
                : Border.all(color: AppColors.amber100, width: 1.2),
            boxShadow: widget.filled
                ? [
                    BoxShadow(
                      color: AppColors.amber700.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: widget.filled ? Colors.white : AppColors.amber800,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

const _features = [
  _FeatureItem(
    Icons.calendar_month_rounded,
    'Live Deployments',
    'View live watchmen assignments, map stations, and request shift coverage seamlessly.',
  ),
  _FeatureItem(
    Icons.fact_check_rounded,
    'Attendance Hub',
    'Securely submit headcounts, log service logs, and review historical attendance trends.',
  ),
  _FeatureItem(
    Icons.forum_rounded,
    'Teammate Comms',
    'Post real-time announcements to the digital bulletin and message other ushers.',
  ),
  _FeatureItem(
    Icons.notifications_active_rounded,
    'Instant Alerts',
    'Receive live push updates whenever new assignments are posted or approvals occur.',
  ),
];

class _FeatureGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) {
        final feature = _features[i];
        return FadeSlideIn(
          delay: Duration(milliseconds: 420 + i * 110),
          child: _FeatureCard(feature: feature),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _FeatureItem feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.amber50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, size: 19, color: AppColors.amber800),
          ),
          const SizedBox(height: 12),
          Text(
            feature.title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: AppColors.slate800,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              feature.description,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.slate400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
