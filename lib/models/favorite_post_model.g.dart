// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FavoritePostModel _$FavoritePostModelFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FavoritePostModel', json, ($checkedConvert) {
      final val = FavoritePostModel(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        userId: $checkedConvert('userId', (v) => (v as num).toInt()),
        title: $checkedConvert('title', (v) => v as String),
        body: $checkedConvert('body', (v) => v as String),
        isLocal: $checkedConvert('isLocal', (v) => v as bool),
        savedAt: $checkedConvert('savedAt', (v) => DateTime.parse(v as String)),
      );
      return val;
    });

Map<String, dynamic> _$FavoritePostModelToJson(FavoritePostModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'body': instance.body,
      'isLocal': instance.isLocal,
      'savedAt': instance.savedAt.toIso8601String(),
    };
