import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment {
  production,
  testing,
}

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String baseUrl;
  final String firebaseProjectName;
  final bool isProduction;

  AppConfig({
    required this.environment,
    required this.appName,
    required this.baseUrl,
    required this.firebaseProjectName,
    required this.isProduction,
  });

  factory AppConfig.production() {
    return AppConfig(
      environment: AppEnvironment.production,
      appName: 'Scholo Admin',
      baseUrl: 'https://admin.scholo.site',
      firebaseProjectName: 'scholo-c927b',
      isProduction: true,
    );
  }

  factory AppConfig.testing() {
    return AppConfig(
      environment: AppEnvironment.testing,
      appName: 'Scholo Admin TEST',
      baseUrl: 'https://test.scholo.site',
      firebaseProjectName: 'scholo-test-project', // Replace with your test project ID
      isProduction: false,
    );
  }
}

/// 🌍 Global provider for App Configuration
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in ProviderScope');
});
