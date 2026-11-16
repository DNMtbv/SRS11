import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/state_views.dart';
import '../../../core/di/injection.dart';
import '../../domain/entities/post_draft.dart';
import '../bloc/create_post/create_post_cubit.dart';
import '../utils/failure_message.dart';
import '../utils/form_validators.dart';

/// Форма нового поста. При успехе возвращает созданный `Post` через pop.
class CreatePostPage extends StatelessWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreatePostCubit>()..loadAuthors(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Новый пост')),
        body: BlocBuilder<CreatePostCubit, CreatePostState>(
          buildWhen: (a, b) =>
              a.authorsStatus != b.authorsStatus || a.authors != b.authors,
          builder: (context, state) => switch (state.authorsStatus) {
            AuthorsStatus.loading => const LoadingView(),
            AuthorsStatus.error => MessageView(
                icon: state.failure?.icon ?? Icons.people_outline,
                title: 'Не удалось загрузить список авторов',
                message: state.failure?.message,
                actionLabel: 'Повторить',
                onAction: () => context.read<CreatePostCubit>().loadAuthors(),
              ),
            AuthorsStatus.empty => MessageView(
                icon: Icons.people_outline,
                title: 'Авторов нет',
                message: 'Сервер вернул пустой список авторов.',
                actionLabel: 'Обновить',
                onAction: () => context.read<CreatePostCubit>().loadAuthors(),
              ),
            AuthorsStatus.success => const _CreatePostForm(),
          },
        ),
      ),
    );
  }
}

class _CreatePostForm extends StatefulWidget {
  const _CreatePostForm();

  @override
  State<_CreatePostForm> createState() => _CreatePostFormState();
}

class _CreatePostFormState extends State<_CreatePostForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _userId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<CreatePostCubit>().submit(
          userId: _userId,
          title: _title.text,
          body: _body.text,
        );
  }

  Future<void> _showServerResponse(CreatedPost created) async {
    final post = created.post;
    final response = const JsonEncoder.withIndent('  ').convert({
      'id': created.serverId,
      'userId': post.userId,
      'title': post.title,
      'body': post.body,
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline),
        title: const Text('Пост отправлен'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ответ сервера (201):'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  response,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'JSONPlaceholder не сохраняет данные, поэтому пост добавлен '
                'в список с пометкой «создан локально» (№ ${post.id}).',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('К списку'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(post);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreatePostCubit, CreatePostState>(
      listenWhen: (a, b) => a.submitStatus != b.submitStatus,
      listener: (context, state) {
        final created = state.created;
        if (state.submitStatus == SubmitStatus.success && created != null) {
          _showServerResponse(created);
        } else if (state.submitStatus == SubmitStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.failure?.message ?? 'Не удалось отправить'),
              action: SnackBarAction(label: 'Повторить', onPressed: _submit),
            ),
          );
        }
      },
      builder: (context, state) {
        final locked =
            state.isSubmitting || state.submitStatus == SubmitStatus.success;
        return Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _userId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Автор',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  for (final a in state.authors)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                validator: PostValidators.userId,
                onChanged: locked ? null : (v) => setState(() => _userId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                enabled: !locked,
                maxLength: PostDraft.titleMax,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  helperText:
                      'От ${PostDraft.titleMin} до ${PostDraft.titleMax} символов',
                ),
                validator: PostValidators.title,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                enabled: !locked,
                minLines: 4,
                maxLines: 10,
                maxLength: PostDraft.bodyMax,
                decoration: const InputDecoration(
                  labelText: 'Текст',
                  alignLabelWithHint: true,
                  helperText:
                      'От ${PostDraft.bodyMin} до ${PostDraft.bodyMax} символов',
                ),
                validator: PostValidators.body,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                // Пока идёт запрос — кнопка заблокирована.
                onPressed: locked ? null : _submit,
                icon: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(state.isSubmitting ? 'Отправка…' : 'Опубликовать'),
              ),
            ],
          ),
        );
      },
    );
  }
}
