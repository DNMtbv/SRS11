import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'src/domain/usecases/registration_usecases.dart';
import 'src/presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Все зависимости собираются в одном месте: core/di/injection.dart.
  await configureDependencies();

  final isRegistered = await getIt<CheckRegistrationUseCase>()();
  runApp(PostsApp(isRegistered: isRegistered));
}
