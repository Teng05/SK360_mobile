import 'package:flutter/material.dart';
import '../ui/app_ui.dart';

class CommunityAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  const CommunityAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first)
        .join()
        .toUpperCase();
    final fallback = Center(
      child: Text(
        initials.isEmpty ? 'SK' : initials,
        style: TextStyle(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w700,
          fontSize: radius * .65,
        ),
      ),
    );
    return Container(
      width: radius * 2,
      height: radius * 2,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.softPink,
        shape: BoxShape.circle,
      ),
      child: photoUrl?.isNotEmpty == true
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}
