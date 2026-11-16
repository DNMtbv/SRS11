import '../either.dart';
import '../error/failures.dart';

/// Базовый контракт UseCase: одно бизнес-действие, результат — Either.
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Параметры для UseCase, которому ничего не нужно.
final class NoParams {
  const NoParams();
}
