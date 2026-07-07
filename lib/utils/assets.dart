// lib/utils/assets.dart

class Assets {
  Assets._();

  // Root folders
  static const String _imagesPath = 'assets/images';
  static const String _iconsPath = 'assets/icons';
  static const String _animationsPath = 'assets/animations';

  // App logo (we can use an SVG or PNG if available, otherwise we use standard Flutter icons / custom painted canvas for MOIL logo)
  static const String logo = '$_imagesPath/moil_logo.png';

  // Icons
  static const String homeIcon = '$_iconsPath/home.svg';
  static const String leaveIcon = '$_iconsPath/leave.svg';
  static const String tourIcon = '$_iconsPath/tour.svg';
  static const String profileIcon = '$_iconsPath/profile.svg';

  // Animations
  static const String successAnim = '$_animationsPath/success.json';
  static const String loadingAnim = '$_animationsPath/loading.json';
}
