import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:practicevskodin/models/comment_model.dart';
import 'package:practicevskodin/models/post_model.dart';
import 'package:practicevskodin/models/registered_user_model.dart';
import 'package:practicevskodin/models/user_model.dart';
import 'package:practicevskodin/src/data/mapper/author_mapper.dart';
import 'package:practicevskodin/src/data/mapper/comment_mapper.dart';
import 'package:practicevskodin/src/data/mapper/post_mapper.dart';
import 'package:practicevskodin/src/domain/entities/author.dart';
import 'package:practicevskodin/src/domain/entities/post.dart';
import 'package:practicevskodin/src/domain/entities/posts_page.dart';

void main() {
  group('PostModel (DTO)', () {
    test('JSON → DTO → Entity', () {
      final post = PostModel.fromJson({
        'userId': 3,
        'id': 21,
        'title': 'asperiores ea ipsam',
        'body': 'line 1\nline 2',
      }).toEntity();

      expect(
        post,
        const Post(
          id: 21,
          userId: 3,
          title: 'asperiores ea ipsam',
          body: 'line 1\nline 2',
        ),
      );
    });

    test('Entity → DTO → JSON без служебного флага isLocal', () {
      const post =
          Post(id: 7, userId: 2, title: 'Title', body: 'Body', isLocal: true);

      expect(post.toModel().toJson(), {
        'id': 7,
        'userId': 2,
        'title': 'Title',
        'body': 'Body',
      });
    });

    test('битый JSON даёт CheckedFromJsonException, а не падение', () {
      expect(
        () => PostModel.fromJson({'id': 'not-a-number', 'userId': 1}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });

  test('избранное хранит isLocal и время добавления', () {
    const post = Post(id: 5, userId: 1, title: 't', body: 'b', isLocal: true);
    final saved = DateTime.utc(2026, 11, 17);

    final model = post.toFavoriteModel(saved);

    expect(model.savedAt, saved);
    expect(model.toEntity(), post);
  });

  test('JSON → UserModel игнорирует лишние поля → Author', () {
    final author = UserModel.fromJson({
      'id': 1,
      'name': 'Leanne Graham',
      'username': 'Bret',
      'email': 'Sincere@april.biz',
      'address': {'city': 'Gwenborough'},
      'website': 'hildegard.org',
    }).toEntity();

    expect(
      author,
      const Author(
        id: 1,
        name: 'Leanne Graham',
        username: 'Bret',
        email: 'Sincere@april.biz',
        website: 'hildegard.org',
      ),
    );
  });

  test('JSON → CommentModel → Comment', () {
    final comment = CommentModel.fromJson({
      'postId': 1,
      'id': 5,
      'name': 'vero eaque',
      'email': 'Hayden@althea.biz',
      'body': 'harum non quasi',
    }).toEntity();
    expect(comment.postId, 1);
    expect(comment.email, 'Hayden@althea.biz');
  });

  test('RegisteredUserModel → JSON без пустых полей', () {
    const user =
        RegisteredUserModel(name: 'A', email: 'a@b.c', phone: '1234567890');
    expect(user.toJson(), {
      'name': 'A',
      'email': 'a@b.c',
      'phone': '1234567890',
    });
  });

  test('ключ кэша и параметр сортировки зависят от запроса', () {
    expect(const PostsQuery().cacheKey, 'user=all;order=asc');
    expect(
      const PostsQuery(userId: 3, order: SortOrder.desc).cacheKey,
      'user=3;order=desc',
    );
  });
}
