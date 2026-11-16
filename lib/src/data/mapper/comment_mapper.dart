import '../../../models/comment_model.dart';
import '../../domain/entities/comment.dart';

extension CommentModelMapper on CommentModel {
  Comment toEntity() =>
      Comment(id: id, postId: postId, name: name, email: email, body: body);
}
