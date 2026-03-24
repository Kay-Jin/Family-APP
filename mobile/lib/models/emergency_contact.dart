class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.userDisplayName,
    required this.contactName,
    required this.relation,
    required this.phone,
    required this.city,
    required this.medicalNotes,
    required this.isPrimary,
  });

  final int id;
  final int familyId;
  final int userId;
  final String userDisplayName;
  final String contactName;
  final String relation;
  final String phone;
  final String city;
  final String medicalNotes;
  final bool isPrimary;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      userId: json['user_id'] as int,
      userDisplayName: (json['user_display_name'] ?? 'Unknown') as String,
      contactName: json['contact_name'] as String,
      relation: json['relation'] as String,
      phone: json['phone'] as String,
      city: (json['city'] ?? '') as String,
      medicalNotes: (json['medical_notes'] ?? '') as String,
      isPrimary: ((json['is_primary'] ?? 0) as int) == 1,
    );
  }
}
