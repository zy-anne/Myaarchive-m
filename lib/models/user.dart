/// User account model matching Myaarchive local auth schema.
class User {
  final String id;
  final String username;
  final String? createdAt;
  final String? securityQuestion;

  const User({
    required this.id,
    required this.username,
    this.createdAt,
    this.securityQuestion,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      securityQuestion: json['security_question']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'created_at': createdAt,
        'security_question': securityQuestion,
      };
}
