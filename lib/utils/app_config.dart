// lib/utils/app_config.dart

class AppConfig {
  AppConfig._();

  static const String appName = 'MOIL LMS';
  static const String appVersion = '1.0.0';
  
  // API Configurations
  static const String baseUrl = 'http://localhost:3000'; // Replace with Next.js backend URL
  static const int connectTimeout = 5000; // milliseconds
  static const int receiveTimeout = 3000; // milliseconds
}
