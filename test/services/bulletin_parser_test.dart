import 'package:flutter_test/flutter_test.dart';
import 'package:gate_guardians/models/bulletin_block.dart';
import 'package:gate_guardians/services/bulletin_parser.dart';

void main() {
  test('a single short bulletin is just a header', () {
    final blocks =
        parseBulletin('Let our service be a blessing to all who enter these gates.');

    expect(blocks, hasLength(1));
    expect(blocks.single, isA<BulletinHeader>());
    expect((blocks.single as BulletinHeader).text,
        'Let our service be a blessing to all who enter these gates.');
  });

  test('parses the full spec example into header, paragraphs, team updates, and closing',
      () {
    const raw = '''
Good evening, all

Hope you've had a blessed week.

A few changes to Sunday's schedule.

Louis
Matthias
Brittnae
Brandt
Terrell
Robert

Have a blessed weekend.

Love y'all!
''';

    final blocks = parseBulletin(raw);

    expect(blocks, hasLength(6));
    expect(blocks[0], isA<BulletinHeader>());
    expect((blocks[0] as BulletinHeader).text, 'Good evening, all');

    expect(blocks[1], isA<BulletinParagraph>());
    expect((blocks[1] as BulletinParagraph).text, "Hope you've had a blessed week.");

    expect(blocks[2], isA<BulletinParagraph>());
    expect((blocks[2] as BulletinParagraph).text, "A few changes to Sunday's schedule.");

    expect(blocks[3], isA<BulletinTeamUpdates>());
    expect((blocks[3] as BulletinTeamUpdates).names,
        ['Louis', 'Matthias', 'Brittnae', 'Brandt', 'Terrell', 'Robert']);

    expect(blocks[4], isA<BulletinParagraph>());
    expect((blocks[4] as BulletinParagraph).text, 'Have a blessed weekend.');

    expect(blocks[5], isA<BulletinClosing>());
    expect((blocks[5] as BulletinClosing).text, "Love y'all!");
  });

  test('detects a name list with no header/closing around it', () {
    const raw = 'Louis\nMatthias\nBrandt\nTerrell';

    final blocks = parseBulletin(raw);

    expect(blocks, hasLength(1));
    expect(blocks.single, isA<BulletinTeamUpdates>());
    expect((blocks.single as BulletinTeamUpdates).names,
        ['Louis', 'Matthias', 'Brandt', 'Terrell']);
  });

  test('does not treat a 2-line list as team updates (below the 3-name threshold)', () {
    // "Announcement:" (with the colon) is what stops it from being read as
    // a 3rd name itself — a bare "Announcement" is indistinguishable from a
    // one-word name and would legitimately extend the run.
    const raw = 'Announcement:\n\nLouis\nMatthias\n\nThanks!';

    final blocks = parseBulletin(raw);

    expect(blocks.whereType<BulletinTeamUpdates>(), isEmpty);
    expect(blocks, hasLength(4));
    expect((blocks[1] as BulletinParagraph).text, 'Louis');
    expect((blocks[2] as BulletinParagraph).text, 'Matthias');
  });

  test('bridges a name list across a stray blank line and no blank line before it '
      '(the exact bug: header/paragraphs ran straight into the names, and a blank '
      'line appeared mid-roster, splitting off a too-short tail)', () {
    const raw = 'Good evening,  all\n'
        "Hope you've had a Blessed week.\n"
        'A few changes to the schedule for Sunday\n'
        'Louis\n'
        'Matthias\n'
        'Brittnae\n'
        'Brandt\n'
        '\n'
        'Terrell\n'
        'Robert\n'
        '\n'
        'Have a Blessed weekend\n'
        "Love ya'll";

    final blocks = parseBulletin(raw);
    final teamBlocks = blocks.whereType<BulletinTeamUpdates>().toList();

    expect(teamBlocks, hasLength(1));
    expect(teamBlocks.single.names,
        ['Louis', 'Matthias', 'Brittnae', 'Brandt', 'Terrell', 'Robert']);
    expect(blocks.first, isA<BulletinHeader>());
    expect((blocks.first as BulletinHeader).text, 'Good evening,  all');
    expect(blocks.last, isA<BulletinClosing>());
    expect((blocks.last as BulletinClosing).text, "Love ya'll");
  });

  test('does not misdetect ordinary sentences broken over lines as a name list', () {
    const raw = 'Reminder\n\n'
        'Please remember\n'
        'to arrive early\n'
        'for the meeting\n\n'
        'Thanks.';

    final blocks = parseBulletin(raw);

    expect(blocks.whereType<BulletinTeamUpdates>(), isEmpty);
  });

  test('ignores blank/whitespace-only input', () {
    expect(parseBulletin(''), isEmpty);
    expect(parseBulletin('   \n\n  '), isEmpty);
  });

  test('a trailing single paragraph is closing, not header, when more than one paragraph exists',
      () {
    final blocks = parseBulletin('Hello team\n\nSee you Sunday.');

    expect(blocks, hasLength(2));
    expect(blocks[0], isA<BulletinHeader>());
    expect(blocks[1], isA<BulletinClosing>());
  });

  group('role tagging', () {
    test('parses "Name - Role" into a TeamUpdateEntry with a role', () {
      const raw = 'Louis\nMatthias\nRobert - Lead Usher';

      final blocks = parseBulletin(raw);
      final entries = (blocks.single as BulletinTeamUpdates).entries;

      expect(entries[0], const TeamUpdateEntryMatcher('Louis', null));
      expect(entries[1], const TeamUpdateEntryMatcher('Matthias', null));
      expect(entries[2], const TeamUpdateEntryMatcher('Robert', 'Lead Usher'));
    });

    test('also accepts an em dash separator', () {
      const raw = 'Louis\nMatthias\nRobert — Lead Usher';

      final blocks = parseBulletin(raw);
      final entries = (blocks.single as BulletinTeamUpdates).entries;

      expect(entries[2], const TeamUpdateEntryMatcher('Robert', 'Lead Usher'));
    });

    test('rejects a role-shaped line whose "name" part is not name-like', () {
      // "Reminder - please read" isn't a roster entry; the left side reads
      // like a sentence fragment, not a name.
      expect(parseTeamLine('Reminder - please read carefully'), isNull);
    });

    test("BulletinTeamUpdates.names still exposes plain name strings", () {
      const raw = 'Louis\nMatthias\nRobert - Lead Usher';

      final team = parseBulletin(raw).single as BulletinTeamUpdates;

      expect(team.names, ['Louis', 'Matthias', 'Robert']);
    });

    test('toLine re-serializes an entry back to its typed form', () {
      expect(const TeamUpdateEntry('Robert').toLine(), 'Robert');
      expect(const TeamUpdateEntry('Robert', 'Lead Usher').toLine(), 'Robert - Lead Usher');
    });
  });
}

/// Matches a [TeamUpdateEntry] by name/role without depending on
/// TeamUpdateEntry having value equality.
class TeamUpdateEntryMatcher extends Matcher {
  const TeamUpdateEntryMatcher(this.name, this.role);
  final String name;
  final String? role;

  @override
  bool matches(Object? item, Map matchState) =>
      item is TeamUpdateEntry && item.name == name && item.role == role;

  @override
  Description describe(Description description) =>
      description.add('TeamUpdateEntry($name, $role)');
}
