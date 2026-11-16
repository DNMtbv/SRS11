import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/state_views.dart';
import '../../domain/entities/post.dart';
import '../bloc/favorites/favorites_cubit.dart';
import '../bloc/posts/posts_bloc.dart';
import '../utils/failure_message.dart';
import '../widgets/cached_banner.dart';
import '../widgets/filters_panel.dart';
import '../widgets/post_card.dart';
import 'create_post_page.dart';
import 'favorites_page.dart';
import 'post_details_page.dart';
import 'registration_page.dart';

class PostsPage extends StatelessWidget {
  const PostsPage({super.key});

  Future<void> _openCreate(BuildContext context) async {
    final bloc = context.read<PostsBloc>();
    final created = await Navigator.of(context).push<Post>(
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
    if (created != null) bloc.add(PostsLocalPostAdded(created));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Посты'),
        actions: [
          const _FavoritesAction(),
          IconButton(
            tooltip: 'Регистрация',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegistrationPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Новый пост'),
      ),
      body: const Column(
        children: [
          FiltersPanel(),
          CachedBanner(),
          Expanded(child: _PostsBody()),
        ],
      ),
    );
  }
}

/// Кнопка «Избранное» со счётчиком.
class _FavoritesAction extends StatelessWidget {
  const _FavoritesAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      buildWhen: (a, b) => a.count != b.count,
      builder: (context, state) => IconButton(
        tooltip: 'Избранное',
        icon: Badge(
          isLabelVisible: state.count > 0,
          label: Text('${state.count}'),
          child: const Icon(Icons.favorite_border),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FavoritesPage()),
        ),
      ),
    );
  }
}

class _PostsBody extends StatelessWidget {
  const _PostsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostsBloc, PostsState>(
      buildWhen: (a, b) => a.status != b.status || a.failure != b.failure,
      builder: (context, state) {
        final bloc = context.read<PostsBloc>();
        switch (state.status) {
          case PostsStatus.initial:
          case PostsStatus.loading:
            return const LoadingView();
          case PostsStatus.error:
            final failure = state.failure;
            return MessageView(
              icon: failure?.icon ?? Icons.error_outline,
              title: 'Не удалось загрузить посты',
              message: failure?.message,
              actionLabel: 'Повторить',
              onAction: () => bloc.add(const PostsRetryRequested()),
            );
          case PostsStatus.empty:
            return RefreshIndicator(
              onRefresh: () => _refresh(bloc),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  MessageView(
                    icon: Icons.inbox_outlined,
                    title: 'Постов нет',
                    message: 'Сервер вернул пустой список для этих фильтров.',
                    actionLabel: 'Сбросить фильтры',
                    actionIcon: Icons.filter_alt_off_outlined,
                    onAction: () => bloc.add(const PostsFiltersReset()),
                  ),
                ],
              ),
            );
          case PostsStatus.success:
          case PostsStatus.cached:
            return const _PostsList();
        }
      },
    );
  }
}

/// pull-to-refresh ждёт, пока блок закончит обновление.
Future<void> _refresh(PostsBloc bloc) async {
  bloc.add(const PostsRefreshRequested());
  await bloc.stream.firstWhere(
    (s) => !s.isRefreshing && s.status != PostsStatus.loading,
  );
}

class _PostsList extends StatefulWidget {
  const _PostsList();

  @override
  State<_PostsList> createState() => _PostsListState();
}

class _PostsListState extends State<_PostsList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<PostsBloc>().add(const PostsNextPageRequested());
    }
  }

  /// Если список не заполнил экран, скролла не будет — догружаем сами.
  void _fillViewportIfNeeded(PostsState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (state.search.isEmpty &&
          state.hasMore &&
          _controller.position.maxScrollExtent <= 0) {
        context.read<PostsBloc>().add(const PostsNextPageRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PostsBloc>();
    return BlocConsumer<PostsBloc, PostsState>(
      listenWhen: (a, b) => a.posts.length != b.posts.length,
      listener: (_, state) => _fillViewportIfNeeded(state),
      builder: (context, state) {
        final posts = state.visiblePosts;
        return RefreshIndicator(
          onRefresh: () => _refresh(bloc),
          child: ListView.builder(
            controller: _controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == posts.length) {
                return _ListFooter(state: state, isEmpty: posts.isEmpty);
              }
              final post = posts[index];
              return PostCard(
                key: ValueKey('${post.isLocal ? 'local' : 'remote'}-${post.id}'),
                post: post,
                authorName: state.authorById(post.userId)?.name,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailsPage(post: post),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Низ списка: индикатор подгрузки / «Повторить» / конец списка.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.isEmpty});

  final PostsState state;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PostsBloc>();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final Widget child;
    if (state.pageStatus == PageLoadStatus.loading) {
      child = const CircularProgressIndicator();
    } else if (state.pageStatus == PageLoadStatus.error) {
      child = Column(
        children: [
          Text(
            state.pageFailure?.message ?? 'Не удалось загрузить страницу',
            textAlign: TextAlign.center,
            style: muted,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => bloc.add(const PostsNextPageRequested()),
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      );
    } else if (state.search.isNotEmpty) {
      child = Column(
        children: [
          if (isEmpty)
            Text('Среди загруженных постов ничего не найдено', style: muted),
          if (state.hasMore) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => bloc.add(const PostsNextPageRequested()),
              child: const Text('Загрузить ещё посты для поиска'),
            ),
          ],
        ],
      );
    } else if (!state.hasMore) {
      child = Text(
        'Больше постов нет (загружено страниц: ${state.page})',
        style: muted,
      );
    } else {
      child = const SizedBox(height: 24);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Center(child: child),
    );
  }
}
