import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../constants/app_theme.dart';
import '../../core/di/injection.dart';
import 'bloc/favorites/favorites_cubit.dart';
import 'bloc/posts/posts_bloc.dart';
import 'pages/posts_page.dart';
import 'pages/registration_page.dart';
import 'utils/failure_message.dart';

class PostsApp extends StatefulWidget {
  const PostsApp({super.key, required this.isRegistered});

  /// Пока пользователь не зарегистрирован, первым открывается
  /// экран регистрации.
  final bool isRegistered;

  @override
  State<PostsApp> createState() => _PostsAppState();
}

class _PostsAppState extends State<PostsApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Общие для всего приложения состояния; BLoC берутся из DI.
        BlocProvider(create: (_) => getIt<PostsBloc>()..add(const PostsStarted())),
        BlocProvider(create: (_) => getIt<FavoritesCubit>()..load()),
      ],
      child: BlocListener<FavoritesCubit, FavoritesState>(
        // Ошибку записи избранного показываем один раз, на любом экране.
        listenWhen: (a, b) =>
            b.actionFailure != null && a.actionFailure != b.actionFailure,
        listener: (context, state) => _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(state.actionFailure!.message)),
          ),
        child: MaterialApp(
          scaffoldMessengerKey: _messengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Посты',
          theme: AppTheme.light(),
          home: widget.isRegistered
              ? const PostsPage()
              : const RegistrationPage(isInitial: true),
        ),
      ),
    );
  }
}
