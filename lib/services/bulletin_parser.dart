import '../models/bulletin_block.dart';

/// Splits raw bulletin text into structural blocks. Each line the author
/// writes becomes its own block — the first is a [BulletinHeader], the last
/// a [BulletinClosing], everything in between a [BulletinParagraph] — except
/// a run of three or more consecutive name-like lines, which becomes a
/// single [BulletinTeamUpdates] roster instead of prose. A name may
/// optionally carry a role for the week, e.g. "Robert - Lead Usher".
///
/// Blank lines are just ignored (ushers rarely bother with them
/// consistently); only the line breaks the author actually typed matter.
/// The author writes plain text — no special formatting is required, and a
/// name list is recognized no matter where it falls relative to other
/// lines.
List<BulletinBlock> parseBulletin(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  if (lines.isEmpty) return const [];

  final run = _findNameRun(lines);
  if (run == null) {
    return _classify(lines);
  }

  final (start, end) = run;
  final before = lines.sublist(0, start);
  final entries = [for (final l in lines.sublist(start, end)) parseTeamLine(l)!];
  final after = lines.sublist(end);

  return [
    ..._classify(before, isLastOverall: after.isEmpty),
    BulletinTeamUpdates(entries),
    ..._classify(after, isFirstOverall: before.isEmpty),
  ];
}

/// First line = Header, last = Closing, rest = Paragraph. [isFirstOverall]/
/// [isLastOverall] let a caller say "this sub-list isn't actually the
/// start/end of the whole document" (paragraphs after a detected name run
/// are never the document's Header, for instance).
List<BulletinBlock> _classify(
  List<String> lines, {
  bool isFirstOverall = true,
  bool isLastOverall = true,
}) {
  return [
    for (var i = 0; i < lines.length; i++)
      if (isFirstOverall && i == 0)
        BulletinHeader(lines[i])
      else if (isLastOverall && i == lines.length - 1)
        BulletinClosing(lines[i])
      else
        BulletinParagraph(lines[i]),
  ];
}

/// Finds the longest run of 3+ consecutive name-like lines. Returns the
/// [start, end) index range into [lines].
(int, int)? _findNameRun(List<String> lines) {
  (int, int)? best;
  var i = 0;
  while (i < lines.length) {
    if (parseTeamLine(lines[i]) == null) {
      i++;
      continue;
    }
    var j = i;
    while (j < lines.length && parseTeamLine(lines[j]) != null) {
      j++;
    }
    if (j - i >= 3 && (best == null || (j - i) > (best.$2 - best.$1))) {
      best = (i, j);
    }
    i = j;
  }
  return best;
}

final _roleSeparator = RegExp(r'^(.+?)\s+[-–—]\s+(.+)$');

/// Parses a single line as a roster entry, e.g. "Robert" or
/// "Robert - Lead Usher". Returns null if the line doesn't look like either.
TeamUpdateEntry? parseTeamLine(String line) {
  final withRole = _roleSeparator.firstMatch(line);
  if (withRole != null) {
    final name = withRole.group(1)!.trim();
    final role = withRole.group(2)!.trim();
    if (_looksLikeName(name) && _looksLikeRole(role)) {
      return TeamUpdateEntry(name, role);
    }
    return null;
  }
  return _looksLikeName(line) ? TeamUpdateEntry(line) : null;
}

/// A short, punctuation-free, title-cased phrase — the kind of thing a
/// person's name (or a short role like "Lead Usher") looks like, as
/// opposed to a sentence.
bool _looksLikeName(String s) {
  if (s.isEmpty || s.length > 30) return false;
  if (RegExp(r'[.!?,:;]$').hasMatch(s)) return false;

  final words = s.split(RegExp(r'\s+'));
  if (words.isEmpty || words.length > 4) return false;

  return words.every((w) => RegExp(r"^[A-Z][a-zA-Z'.-]*$").hasMatch(w));
}

/// Roles use the same title-case-phrase shape as names.
bool _looksLikeRole(String s) => _looksLikeName(s);
