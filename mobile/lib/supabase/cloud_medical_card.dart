class CloudMedicalCard {
  CloudMedicalCard({
    required this.familyId,
    required this.userId,
    this.displayName,
    this.allergies,
    this.medications,
    this.hospitals,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.accompanimentNote,
    required this.updatedAt,
  });

  final String familyId;
  final String userId;
  final String? displayName;
  final String? allergies;
  final String? medications;
  final String? hospitals;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? accompanimentNote;
  final DateTime updatedAt;

  factory CloudMedicalCard.fromJson(Map<String, dynamic> json) {
    return CloudMedicalCard(
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      allergies: json['allergies'] as String?,
      medications: json['medications'] as String?,
      hospitals: json['hospitals'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      accompanimentNote: json['accompaniment_note'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
