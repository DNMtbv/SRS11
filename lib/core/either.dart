/// Результат операции: либо ошибка [L] (Left), либо значение [R] (Right).
///
/// Своя маленькая реализация вместо dartz/fpdart: этого достаточно, чтобы
/// репозитории и UseCase возвращали ошибку как значение, а не бросали её.
sealed class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  /// Значение, если это Right, иначе null.
  R? get rightOrNull => switch (this) {
        Right(:final value) => value,
        Left() => null,
      };

  /// Ошибка, если это Left, иначе null.
  L? get leftOrNull => switch (this) {
        Left(:final value) => value,
        Right() => null,
      };

  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) =>
      switch (this) {
        Left(:final value) => onLeft(value),
        Right(:final value) => onRight(value),
      };

  Either<L, T> map<T>(T Function(R right) transform) => switch (this) {
        Left(:final value) => Left(value),
        Right(:final value) => Right(transform(value)),
      };
}

final class Left<L, R> extends Either<L, R> {
  const Left(this.value);

  final L value;

  @override
  bool operator ==(Object other) => other is Left<L, R> && other.value == value;

  @override
  int get hashCode => Object.hash('Left', value);

  @override
  String toString() => 'Left($value)';
}

final class Right<L, R> extends Either<L, R> {
  const Right(this.value);

  final R value;

  @override
  bool operator ==(Object other) =>
      other is Right<L, R> && other.value == value;

  @override
  int get hashCode => Object.hash('Right', value);

  @override
  String toString() => 'Right($value)';
}

/// Тип «нет значения» для операций, которые ничего не возвращают.
final class Unit {
  const Unit._();

  @override
  String toString() => 'unit';
}

const unit = Unit._();
