// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registered_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisteredUserModel _$RegisteredUserModelFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RegisteredUserModel', json, ($checkedConvert) {
      final val = RegisteredUserModel(
        name: $checkedConvert('name', (v) => v as String),
        email: $checkedConvert('email', (v) => v as String),
        phone: $checkedConvert('phone', (v) => v as String),
        city: $checkedConvert('city', (v) => v as String?),
        fcmToken: $checkedConvert('fcmToken', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$RegisteredUserModelToJson(
  RegisteredUserModel instance,
) => <String, dynamic>{
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'city': ?instance.city,
  'fcmToken': ?instance.fcmToken,
};
