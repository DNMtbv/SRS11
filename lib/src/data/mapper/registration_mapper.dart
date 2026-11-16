import '../../../models/registered_user_model.dart';
import '../../domain/entities/registration_data.dart';

extension RegistrationDataMapper on RegistrationData {
  RegisteredUserModel toModel({String? fcmToken}) => RegisteredUserModel(
        name: name,
        email: email,
        phone: phone,
        city: city,
        fcmToken: fcmToken,
      );
}
