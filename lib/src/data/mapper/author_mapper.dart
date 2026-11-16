import '../../../models/user_model.dart';
import '../../domain/entities/author.dart';

extension UserModelMapper on UserModel {
  Author toEntity() => Author(
        id: id,
        name: name,
        username: username,
        email: email,
        website: website,
      );
}
