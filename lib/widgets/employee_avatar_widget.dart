import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_config.dart';

/// Employee Avatar Widget
/// Efficiently fetches profile photo via single backend streaming endpoint:
/// ${AppConfig.baseUrl}/api/profile-photo/{cleanId}
/// Displays clean generic passport photo placeholder if photo is not present on server.
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

  List<String> _buildCandidateUrls(String rawEmpNo) {
    final cleanId = rawEmpNo.trim().replaceAll(RegExp('^0+'), '');
    if (cleanId.isEmpty) return [];

    return [
      '${AppConfig.baseUrl}/api/profile-photo/$cleanId',
      'https://acubeai.com/test/moil_hr_app/api/profile-photo/$cleanId',
    ];
  }

  Widget _buildPlaceholder() {
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

  Widget _buildCascadedNetworkImage(List<String> urls, int index) {
    if (index >= urls.length) {
      return _buildPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: urls[index],
      fit: fit,
      alignment: Alignment.topCenter,
      errorWidget: (context, url, error) => _buildCascadedNetworkImage(urls, index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _buildCandidateUrls(empNo);

    Widget content = _buildCascadedNetworkImage(urls, 0);

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
