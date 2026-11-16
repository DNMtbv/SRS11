import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/post.dart';
import '../bloc/favorites/favorites_cubit.dart';

/// Сердечко «в избранное». Состояние берёт из общего [FavoritesCubit].
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      buildWhen: (a, b) =>
          a.contains(post.id) != b.contains(post.id) ||
          a.pendingIds.contains(post.id) != b.pendingIds.contains(post.id),
      builder: (context, state) {
        final isFavorite = state.contains(post.id);
        final isPending = state.pendingIds.contains(post.id);
        return IconButton(
          key: ValueKey('favorite-${post.id}'),
          tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
          visualDensity: VisualDensity.compact,
          onPressed: isPending
              ? null
              : () => context.read<FavoritesCubit>().toggle(post),
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Theme.of(context).colorScheme.error : null,
          ),
        );
      },
    );
  }
}
