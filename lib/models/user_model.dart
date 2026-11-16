import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// DTO пользователя из /users. Берём только нужные поля,
/// остальные (address, company…) игнорируются.
@JsonSerializable(checked: true)
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.website,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  final int id;
  final String name;
  final String username;
  final String email;
  final String? website;

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
