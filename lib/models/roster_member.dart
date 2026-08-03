import 'package:cloud_firestore/cloud_firestore.dart';

/// A `team` document as shown in roster/admin management screens. Unlike
/// [TeamProfile], this is the raw doc — it does not follow `linkedTo` —
/// since roster management needs to see and act on every doc directly.
class RosterMember {
  const RosterMember({
    required this.id,
    required this.name,
    required this.role,
    required this.approved,
    required this.denied,
    this.phone,
    this.email,
    this.createdAt,
    this.linkedTo,
  });

  factory RosterMember.fromMap(String id, Map<String, dynamic> data) {
    return RosterMember(
      id: id,
      name: (data['name'] as String?) ?? '—',
      role: (data['role'] as String?) ?? 'Usher',
      approved: data['approved'] == true,
      denied: data['denied'] == true,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      createdAt: _parseDate(data['createdAt']),
      linkedTo: data['linkedTo'] as String?,
    );
  }

  final String id;
  final String name;
  final String role;
  final bool approved;
  final bool denied;
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final String? linkedTo;
}

/// `createdAt` was written as an ISO string by most of the app, but some
/// records (older data, or docs added by hand in the Firebase console)
/// store it as a Firestore [Timestamp] instead — accept either.
DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
