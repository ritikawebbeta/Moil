import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final rawId = rawEmpNo.trim();
    final paddedId = cleanId.padLeft(8, '0');

    final Set<String> ids = {rawId, cleanId, paddedId};
    final List<String> suffixes = ['_self', ''];
    final List<String> exts = ['.jpg', '.png', '.jpeg', '.JPG', '.PNG', '.JPEG'];
    final List<String> folders = [
      'https://wcil.acubeai.com/test/moil_hr_app/uploads/profiles/Photo/',
      'https://wcil.acubeai.com/test/moil_hr_app/uploads/profiles/',
      'https://acubeai.com/test/moil_hr_app/uploads/profiles/Photo/',
      'https://acubeai.com/test/moil_hr_app/uploads/profiles/',
    ];

    final List<String> urls = [];
    for (var folder in folders) {
      for (var id in ids) {
        if (id.isEmpty) continue;
        for (var suffix in suffixes) {
          for (var ext in exts) {
            urls.add('$folder$id$suffix$ext');
          }
        }
      }
    }
    return urls;
  }

  Widget _buildFallbackAsset(String cleanId) {
    if (cleanId == '16194') {
      return Image.asset('assets/images/rakesh_tumane.jpg', fit: fit, alignment: Alignment.topCenter);
    } else if (cleanId == '17110') {
      return Image.asset('assets/images/sameer_banerjee.jpg', fit: fit, alignment: Alignment.topCenter);
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
              ? const Text(
                  'Passport Size\nPhoto',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8, color: Colors.grey),
                )
              : const Icon(Icons.person, color: Colors.grey, size: 18),
        ),
      );
    }
  }

  Widget _buildCascadedNetworkImage(List<String> urls, int index, String cleanId) {
    if (index >= urls.length) {
      return _buildFallbackAsset(cleanId);
    }

    return CachedNetworkImage(
      imageUrl: urls[index],
      fit: fit,
      alignment: Alignment.topCenter,
      errorWidget: (context, url, error) => _buildCascadedNetworkImage(urls, index + 1, cleanId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanId = empNo.trim().replaceAll(RegExp('^0+'), '');
    final urls = _buildCandidateUrls(empNo);

    Widget content = _buildCascadedNetworkImage(urls, 0, cleanId);

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
