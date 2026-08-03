/// A structural piece of a parsed bulletin announcement. The bulletin is
/// authored as plain text; [parseBulletin] (see bulletin_parser.dart) infers
/// this structure automatically so the author never has to format anything.
sealed class BulletinBlock {
  const BulletinBlock();
}

/// The opening line/paragraph of the announcement, rendered larger.
class BulletinHeader extends BulletinBlock {
  const BulletinHeader(this.text);
  final String text;
}

/// A normal body paragraph.
class BulletinParagraph extends BulletinBlock {
  const BulletinParagraph(this.text);
  final String text;
}

/// One roster entry — a name, optionally tagged with a role for that week
/// (e.g. "Robert - Lead Usher").
class TeamUpdateEntry {
  const TeamUpdateEntry(this.name, [this.role]);
  final String name;
  final String? role;

  /// Re-serializes back to the plain-text line form the author typed.
  String toLine() => role == null ? name : '$name - $role';
}

/// A detected list of names — rendered as a roster instead of prose.
class BulletinTeamUpdates extends BulletinBlock {
  const BulletinTeamUpdates(this.entries);
  final List<TeamUpdateEntry> entries;

  List<String> get names => [for (final e in entries) e.name];
}

/// The final paragraph/sign-off of the announcement.
class BulletinClosing extends BulletinBlock {
  const BulletinClosing(this.text);
  final String text;
}
