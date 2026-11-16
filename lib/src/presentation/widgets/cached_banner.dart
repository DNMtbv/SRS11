import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/posts/posts_bloc.dart';
import '../utils/failure_message.dart';

/// Плашка «Показаны сохранённые данные».
class CachedBanner extends StatelessWidget {
  const CachedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostsBloc, PostsState>(
      buildWhen: (a, b) =>
          a.status != b.status ||
          a.isRefreshing != b.isRefreshing ||
          a.failure != b.failure,
      builder: (context, state) {
        if (state.status != PostsStatus.cached) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final reason = state.isRefreshing
            ? 'Обновляем с сервера…'
            : state.failure?.message ?? 'Не удалось обновить данные.';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: scheme.onSecondaryContainer,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Показаны сохранённые данные',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isRefreshing)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton(
                  onPressed: () => context
                      .read<PostsBloc>()
                      .add(const PostsRefreshRequested()),
                  child: const Text('Обновить'),
                ),
            ],
          ),
        );
      },
    );
  }
}
