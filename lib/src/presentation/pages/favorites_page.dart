import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/state_views.dart';
import '../bloc/favorites/favorites_cubit.dart';
import '../bloc/posts/posts_bloc.dart';
import '../utils/failure_message.dart';
import '../widgets/post_card.dart';
import 'post_details_page.dart';

/// Избранное. Хранится на устройстве, поэтому открывается и без сети.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: BlocBuilder<FavoritesCubit, FavoritesState>(
        buildWhen: (a, b) =>
            a.status != b.status ||
            a.favorites != b.favorites ||
            a.failure != b.failure,
        builder: (context, state) {
          final cubit = context.read<FavoritesCubit>();
          switch (state.status) {
            case FavoritesStatus.initial:
            case FavoritesStatus.loading:
              return const LoadingView();
            case FavoritesStatus.error:
              final failure = state.failure;
              return MessageView(
                icon: failure?.icon ?? Icons.error_outline,
                title: 'Не удалось открыть избранное',
                message: failure?.message,
                actionLabel: 'Повторить',
                onAction: cubit.load,
              );
            case FavoritesStatus.empty:
              return const MessageView(
                icon: Icons.favorite_border,
                title: 'В избранном пока пусто',
                message: 'Нажмите ♡ на карточке поста, чтобы сохранить его. '
                    'Избранное доступно и без интернета.',
              );
            case FavoritesStatus.success:
              // Имена авторов берём из уже загруженного списка, если он есть.
              final posts = context.read<PostsBloc>().state;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.favorites.length,
                itemBuilder: (context, index) {
                  final post = state.favorites[index];
                  return PostCard(
                    key: ValueKey('favorite-card-${post.id}'),
                    post: post,
                    authorName: posts.authorById(post.userId)?.name,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailsPage(post: post),
                      ),
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
