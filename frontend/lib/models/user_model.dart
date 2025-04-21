class UserModel {
  final String id;
  final String name;
  final String email;
  final String profileImage;

  UserModel(
      {required this.id,
      required this.name,
      required this.email,
      required this.profileImage});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      profileImage: json['profileImage'] ?? '',
    );
  }
}
