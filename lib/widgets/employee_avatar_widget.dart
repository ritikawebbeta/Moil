import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_config.dart';

/// Employee Avatar Widget
/// Tries network photo from server photo API:
/// ${AppConfig.baseUrl}/api/profile-photo/{cleanId}
/// Falls back to local asset photo or clean passport photo placeholder as previous.
class EmployeeAvatarWidget extends StatelessWidget {
  final String empNo;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showBorder;

  const EmployeeAvatarWidget({
    super.key,
    required this.empNo,
    this.width = 100,
    this.height = 110,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showBorder = false,
  });

  Widget _buildFallbackAsset(String cleanId) {
    if (cleanId == '16194') {
      return Image.asset('assets/images/rakesh_tumane.jpg', fit: fit, alignment: Alignment.topCenter);
    } else if (cleanId == '17110') {
      return Image.asset('assets/images/sameer_banerjee.jpg', fit: fit, alignment: Alignment.topCenter);
    } else if (cleanId == '446') {
      return Image.asset('assets/images/raja_talathoti.jpg', fit: fit, alignment: Alignment.topCenter);
    } else if (cleanId == '540') {
      return Image.asset('assets/images/swapnil_manpe.jpg', fit: fit, alignment: Alignment.topCenter);
    } else if (cleanId == '4410') {
      return Image.asset('assets/images/ranjeet_chouhan.jpg', fit: fit, alignment: Alignment.topCenter);
    } else if (cleanId == '4428') {
      return Image.asset('assets/images/bcn_gautam.jpg', fit: fit, alignment: Alignment.topCenter);
    } else {
      return Container(
        color: Colors.grey.shade100,
        child: Center(
          child: height > 50
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, color: Colors.grey, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'Passport Size\nPhoto',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                )
              : const Icon(Icons.person, color: Colors.grey, size: 18),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanId = empNo.trim().replaceAll(RegExp('^0+'), '');
    final photoUrl = '${AppConfig.baseUrl}/api/profile-photo/$cleanId';

    Widget content = CachedNetworkImage(
      imageUrl: photoUrl,
      fit: fit,
      alignment: Alignment.topCenter,
      errorWidget: (context, url, error) => _buildFallbackAsset(cleanId),
    );

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: showBorder
          ? BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1),
              borderRadius: borderRadius,
            )
          : null,
      child: content,
    );
  }
}
