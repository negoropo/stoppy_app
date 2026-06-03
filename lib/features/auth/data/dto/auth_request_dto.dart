class AuthRequestDto {
  const AuthRequestDto({required this.username, required this.password});

  final String username;
  final String password;

  Map<String, Object?> toJson() {
    return {'username': username, 'password': password};
  }
}
