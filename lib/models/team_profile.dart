/// A resolved `team` roster entry — already following `linkedTo` if the
/// signed-in account is a secondary (e.g. phone) login linked to a primary
/// email record.
class TeamProfile {
  const TeamProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.approved,
    required this.denied,
  });

  factory TeamProfile.fromMap(String id, Map<String, dynamic> data) {
    return TeamProfile(
      id: id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Guardian',
      role: (data['role'] as String?) ?? 'Usher',
      approved: data['approved'] == true,
      denied: data['denied'] == true,
    );
  }

  final String id;
  final String name;
  final String role;
  final bool approved;
  final bool denied;

  bool get isAdmin => role == 'Admin';
}
