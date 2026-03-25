class MedicalCard {
  MedicalCard({
    required this.familyId,
    required this.allergies,
    required this.medications,
    required this.hospitals,
    required this.otherNotes,
    required this.accompanimentRequested,
    required this.accompanimentNote,
  });

  final int familyId;
  final String allergies;
  final String medications;
  final String hospitals;
  final String otherNotes;
  final bool accompanimentRequested;
  final String accompanimentNote;

  factory MedicalCard.fromJson(Map<String, dynamic> json) {
    return MedicalCard(
      familyId: json['family_id'] as int,
      allergies: (json['allergies'] ?? '') as String,
      medications: (json['medications'] ?? '') as String,
      hospitals: (json['hospitals'] ?? '') as String,
      otherNotes: (json['other_notes'] ?? '') as String,
      accompanimentRequested: ((json['accompaniment_requested'] ?? 0) as int) == 1,
      accompanimentNote: (json['accompaniment_note'] ?? '') as String,
    );
  }
}

