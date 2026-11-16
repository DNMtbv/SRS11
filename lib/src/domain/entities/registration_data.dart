import 'package:equatable/equatable.dart';

enum RegistrationField { name, email, phone, city }

/// Данные регистрации + правила их проверки и нормализации.
class RegistrationData extends Equatable {
  const RegistrationData({
    required this.name,
    required this.email,
    required this.phone,
    this.city,
  });

  static const nameMin = 2;
  static const nameMax = 50;
  static const cityMax = 50;
  static const phoneDigitsMin = 10;
  static const phoneDigitsMax = 15;

  static final emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final phonePattern = RegExp(r'^\+?[\d\s()-]+$');

  final String name;
  final String email;
  final String phone;
  final String? city;

  /// Обрезает пробелы, приводит email к нижнему регистру,
  /// пустой город превращает в null.
  RegistrationData normalized() {
    final c = city?.trim();
    return RegistrationData(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      city: (c == null || c.isEmpty) ? null : c,
    );
  }

  Set<RegistrationField> validate() {
    final n = name.trim();
    final e = email.trim();
    final p = phone.trim();
    final digits = p.replaceAll(RegExp(r'\D'), '').length;
    return {
      if (n.length < nameMin || n.length > nameMax) RegistrationField.name,
      if (!emailPattern.hasMatch(e)) RegistrationField.email,
      if (!phonePattern.hasMatch(p) ||
          digits < phoneDigitsMin ||
          digits > phoneDigitsMax)
        RegistrationField.phone,
      if ((city?.trim().length ?? 0) > cityMax) RegistrationField.city,
    };
  }

  @override
  List<Object?> get props => [name, email, phone, city];
}
