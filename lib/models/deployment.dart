/// A single usher's assignment for a service/event, read from the
/// `deployments` collection.
class Deployment {
  const Deployment({
    required this.id,
    required this.date,
    required this.serviceType,
    this.customEventName,
    this.station,
    this.role,
    this.requestingCover = false,
  });

  factory Deployment.fromMap(String id, Map<String, dynamic> data) {
    return Deployment(
      id: id,
      date: (data['date'] as String?) ?? '',
      serviceType: (data['serviceType'] as String?) ?? 'Service',
      customEventName: data['customEventName'] as String?,
      station: data['station'] as String?,
      role: data['role'] as String?,
      requestingCover: data['requestingCover'] == true,
    );
  }

  final String id;
  final String date; // ISO yyyy-MM-dd
  final String serviceType;
  final String? customEventName;
  final String? station;
  final String? role;
  final bool requestingCover;

  String get label =>
      serviceType == 'Events' ? (customEventName ?? 'Special Event') : serviceType;
}
