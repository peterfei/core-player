import 'dart:async';
import 'dart:math';

class RetryHelper {
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffFactor = 2.0,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts || (shouldRetry != null && !shouldRetry(e))) {
          rethrow;
        }
        
        final delay = initialDelay * pow(backoffFactor, attempt - 1);
        await Future.delayed(delay);
      }
    }
  }
}
