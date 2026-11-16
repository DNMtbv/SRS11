import '../../domain/entities/post_draft.dart';
import '../../domain/entities/registration_data.dart';

/// Тексты ошибок под полями формы. Сами границы (5–100 символов и т. д.)
/// берутся из Domain, чтобы форма и UseCase проверяли одно и то же.
abstract final class PostValidators {
  static String? title(String? value) =>
      _length(value, PostDraft.titleMin, PostDraft.titleMax, 'Заголовок');

  static String? body(String? value) =>
      _length(value, PostDraft.bodyMin, PostDraft.bodyMax, 'Текст');

  static String? userId(int? value) =>
      value == null ? 'Выберите автора' : null;

  static String? _length(String? value, int min, int max, String field) {
    final length = (value ?? '').trim().length;
    if (length == 0) return '$field обязателен';
    if (length < min) return '$field: минимум $min символов (сейчас $length)';
    if (length > max) return '$field: максимум $max символов (сейчас $length)';
    return null;
  }
}

abstract final class RegistrationValidators {
  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Введите имя';
    if (v.length < RegistrationData.nameMin) {
      return 'Имя: минимум ${RegistrationData.nameMin} символа';
    }
    if (v.length > RegistrationData.nameMax) {
      return 'Имя: максимум ${RegistrationData.nameMax} символов';
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Введите email';
    if (!RegistrationData.emailPattern.hasMatch(v)) return 'Некорректный email';
    return null;
  }

  /// Допускаются +, пробелы, скобки и дефисы; цифр — от 10 до 15.
  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Введите телефон';
    if (!RegistrationData.phonePattern.hasMatch(v)) {
      return 'Только цифры, +, пробелы, скобки и дефисы';
    }
    final digits = v.replaceAll(RegExp(r'\D'), '').length;
    if (digits < RegistrationData.phoneDigitsMin ||
        digits > RegistrationData.phoneDigitsMax) {
      return 'В номере должно быть '
          '${RegistrationData.phoneDigitsMin}–${RegistrationData.phoneDigitsMax} '
          'цифр';
    }
    return null;
  }

  static String? city(String? value) {
    final v = (value ?? '').trim();
    if (v.length > RegistrationData.cityMax) {
      return 'Город: максимум ${RegistrationData.cityMax} символов';
    }
    return null;
  }
}
