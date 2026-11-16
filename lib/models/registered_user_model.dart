import 'package:json_annotation/json_annotation.dart';

part 'registered_user_model.g.dart';

/// Запись пользователя в Firebase Realtime Database (/users/{key}).
@JsonSerializable(checked: true, includeIfNull: false)
class RegisteredUserModel {
  const RegisteredUserModel({
    required this.name,
    required this.email,
    required this.phone,
    this.city,
    this.fcmToken,
  });

  factory RegisteredUserModel.fromJson(Map<String, dynamic> json) =>
      _$RegisteredUserModelFromJson(json);

  final String name;
  final String email;
  final String phone;
  final String? city;

  /// Токен устройства: по нему можно отправить пуш именно этому пользователю.
  final String? fcmToken;

  Map<String, dynamic> toJson() => _$RegisteredUserModelToJson(this);
}
