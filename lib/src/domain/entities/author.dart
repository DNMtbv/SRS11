import 'package:equatable/equatable.dart';

/// Автор поста (пользователь JSONPlaceholder).
class Author extends Equatable {
  const Author({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.website,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? website;

  @override
  List<Object?> get props => [id, name, username, email, website];
}
