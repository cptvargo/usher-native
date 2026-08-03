import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bulletin_block.dart';
import '../theme/app_colors.dart';

/// Renders a single parsed bulletin block. Dark/tinted context (e.g. the
/// leadership bulletin card) — text defaults to white.
class BulletinBlockView extends StatelessWidget {
  const BulletinBlockView({super.key, required this.block});

  final BulletinBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      BulletinHeader(:final text) => _HeaderText(text),
      BulletinParagraph(:final text) => _BodyText(text),
      BulletinClosing(:final text) => _BodyText(text),
      BulletinTeamUpdates(:final entries) => _TeamUpdates(entries),
    };
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.amber200,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        height: 1.65,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }
}

class _TeamUpdates extends StatelessWidget {
  const _TeamUpdates(this.entries);
  final List<TeamUpdateEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Role-tagged entries (e.g. "Robert - Lead Usher") get their own
    // full-width row so the role is legible; plain names pair up 2-per-row.
    final rows = <Widget>[];
    final pending = <TeamUpdateEntry>[];

    void flushPending() {
      if (pending.isEmpty) return;
      rows.add(Row(
        children: [
          Expanded(child: _NameBullet(pending[0])),
          const SizedBox(width: 12),
          Expanded(child: pending.length > 1 ? _NameBullet(pending[1]) : const SizedBox()),
        ],
      ));
      pending.clear();
    }

    for (final entry in entries) {
      if (entry.role != null) {
        flushPending();
        rows.add(_NameBullet(entry));
      } else {
        pending.add(entry);
        if (pending.length == 2) flushPending();
      }
    }
    flushPending();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.amber700,
                shape: BoxShape.circle,
              ),
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
            const SizedBox(width: 10),
            Expanded(
              child: Container(height: 1, color: AppColors.amber200.withValues(alpha: 0.25)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final row in rows)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: row),
        const SizedBox(height: 4),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
      ],
    );
  }
}

class _NameBullet extends StatelessWidget {
  const _NameBullet(this.entry);
  final TeamUpdateEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.amber200,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: entry.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                if (entry.role != null)
                  TextSpan(
                    text: '   ·   ${entry.role!.toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.amber200.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
