class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? restaurant;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.restaurant,
    this.errorMessage,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        restaurant = null,
        errorMessage = null;

  const AuthState.unauthenticated({String? message})
      : status = AuthStatus.unauthenticated,
        user = null,
        restaurant = null,
        errorMessage = message;

  const AuthState.onboardingRequired({required Map<String, dynamic> user})
      : status = AuthStatus.onboardingRequired,
        this.user = user,
        restaurant = null,
        errorMessage = null;

  const AuthState.authenticated({
    required Map<String, dynamic> user,
    required Map<String, dynamic> restaurant,
  })  : status = AuthStatus.authenticated,
        this.user = user,
        this.restaurant = restaurant,
        errorMessage = null;

  List<String> get roles {
    if (user == null) return [];
    if (user!['roles'] is List) {
      return (user!['roles'] as List).map((r) => r.toString()).toList();
    }
    if (user!['role'] is String) {
      return (user!['role'] as String)
          .split(',')
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toList();
    }
    return [];
  }

  bool get isFinancialAuthorized {
    final userRoles = roles;
    return userRoles.isEmpty || userRoles.contains('Owner') || userRoles.contains('Manager');
  }

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    Map<String, dynamic>? restaurant,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      restaurant: restaurant ?? this.restaurant,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum AuthStatus {
  initial,
  unauthenticated,
  onboardingRequired,
  authenticated,
}
