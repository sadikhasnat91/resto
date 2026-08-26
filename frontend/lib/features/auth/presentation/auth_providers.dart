import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../domain/auth_state.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/network/dio_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dio = ref.watch(dioClientProvider).dio;
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(dio, storage);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final StorageService _storage;

  AuthNotifier(this._dio, this._storage) : super(const AuthState.initial()) {
    restoreSession();
  }

  // --- Restore Session ---
  Future<void> restoreSession() async {
    final token = _storage.getAccessToken();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      // 1. Fetch User details
      final userResponse = await _dio.get('/api/auth/me');
      final userData = userResponse.data as Map<String, dynamic>;
      await _storage.setUser(userData);

      // 2. Fetch Restaurant status
      final restResponse = await _dio.get('/api/onboarding/status');
      if (restResponse.statusCode == 200) {
        final restData = restResponse.data as Map<String, dynamic>;
        
        // Check if name is default or needs onboarding completion
        if (restData['name'] == '' || restData['phone'] == null) {
          state = AuthState.onboardingRequired(user: userData);
        } else {
          await _storage.setRestaurant(restData);
          state = AuthState.authenticated(user: userData, restaurant: restData);
        }
      } else {
        state = AuthState.onboardingRequired(user: userData);
      }
    } catch (e) {
      // If unauthorized, clear session
      await _storage.clearAuth();
      state = const AuthState.unauthenticated();
    }
  }

  // --- Login ---
  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.initial);
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      
      final tokenData = response.data as Map<String, dynamic>;
      await _storage.setAccessToken(tokenData['access_token']);
      await _storage.setRefreshToken(tokenData['refresh_token']);

      // Restore session details
      await restoreSession();
      return state.status == AuthStatus.authenticated || state.status == AuthStatus.onboardingRequired;
    } on DioException catch (e) {
      final message = e.response?.data['detail'] ?? 'Login failed. Please check your credentials.';
      state = AuthState.unauthenticated(message: message.toString());
      return false;
    } catch (e) {
      state = const AuthState.unauthenticated(message: 'An unexpected error occurred.');
      return false;
    }
  }

  // --- Register ---
  Future<bool> register(String email, String password, String name, String restaurantName) async {
    state = state.copyWith(status: AuthStatus.initial);
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': name,
          'restaurant_name': restaurantName
        },
      );

      final tokenData = response.data as Map<String, dynamic>;
      await _storage.setAccessToken(tokenData['access_token']);
      await _storage.setRefreshToken(tokenData['refresh_token']);

      // Session restored will put us in onboarding status since it's a new restaurant
      await restoreSession();
      return true;
    } on DioException catch (e) {
      final message = e.response?.data['detail'] ?? 'Registration failed.';
      state = AuthState.unauthenticated(message: message.toString());
      return false;
    } catch (e) {
      state = const AuthState.unauthenticated(message: 'An unexpected error occurred.');
      return false;
    }
  }

  // --- Onboarding Completion ---
  Future<bool> completeOnboarding(Map<String, dynamic> onboardingData) async {
    try {
      final response = await _dio.post('/api/onboarding', data: onboardingData);
      if (response.statusCode == 200) {
        final restData = response.data as Map<String, dynamic>;
        await _storage.setRestaurant(restData);
        
        final user = _storage.getUser();
        if (user != null) {
          state = AuthState.authenticated(user: user, restaurant: restData);
          return true;
        }
      }
    } catch (e) {
      // Handle onboarding save error
    }
    return false;
  }

  // --- Logout ---
  Future<void> logout() async {
    await _storage.clearAuth();
    state = const AuthState.unauthenticated();
  }

  // --- Update Profile ---
  Future<bool> updateProfile(String name, String phone) async {
    try {
      // Update User Name
      final userResponse = await _dio.put(
        '/api/auth/me',
        data: {'full_name': name},
      );
      
      // Update Restaurant Phone
      final restResponse = await _dio.put(
        '/api/restaurants/me',
        data: {'phone': phone},
      );

      if (userResponse.statusCode == 200 && restResponse.statusCode == 200) {
        final userData = userResponse.data as Map<String, dynamic>;
        final restData = restResponse.data as Map<String, dynamic>;
        
        await _storage.setUser(userData);
        await _storage.setRestaurant(restData);
        
        state = AuthState.authenticated(user: userData, restaurant: restData);
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  // --- Delete Account ---
  Future<bool> deleteAccount() async {
    try {
      final response = await _dio.delete('/api/auth/me');
      if (response.statusCode == 204) {
        await logout();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
