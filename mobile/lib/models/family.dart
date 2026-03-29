class Family {
  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUserId,
    this.myRole = 'member',
    this.familyHasParentRole = false,
  });

  final int id;
  final String name;
  final String inviteCode;
  final int ownerUserId;
  /// From GET /families/:id — `member`, `parent`, `child`, or `owner` (creator before they pick a role).
  final String myRole;
  final bool familyHasParentRole;

  factory Family.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['my_role'] as String?)?.trim().toLowerCase();
    return Family(
      id: json['id'] as int,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      ownerUserId: json['owner_user_id'] as int,
      myRole: (rawRole != null && rawRole.isNotEmpty) ? rawRole : 'member',
      familyHasParentRole: json['family_has_parent_role'] == true,
    );
  }
}
