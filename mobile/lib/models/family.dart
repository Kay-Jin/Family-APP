class Family {
  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUserId,
  });

  final int id;
  final String name;
  final String inviteCode;
  final int ownerUserId;

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as int,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      ownerUserId: json['owner_user_id'] as int,
    );
  }
}
