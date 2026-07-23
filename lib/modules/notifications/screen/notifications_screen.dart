// lib/modules/notifications/screen/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../controller/notification_controller.dart';
import '../../../model/notification_model.dart';
import '../../../widgets/app_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationController>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Notifications',
        actions: [
          Consumer<NotificationController>(
            builder: (context, controller, _) {
              if (controller.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: controller.markAllAsRead,
                child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationController>(
        builder: (context, controller, _) {
          return RefreshIndicator(
            onRefresh: () => controller.fetchNotifications(),
            color: AppColors.primary,
            child: controller.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: 'No Notifications',
                        subtitle: 'You have no notifications at this time.',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.notifications.length,
                    itemBuilder: (context, index) {
                      final notif = controller.notifications[index];
                      return _NotifCard(notif: notif, onTap: () => controller.markAsRead(notif.id));
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  Color get _iconColor {
    final t = notif.type.toLowerCase();
    final title = notif.title.toLowerCase();

    if (title.contains('approved')) return AppColors.success;
    if (title.contains('rejected')) return AppColors.error;
    if (title.contains('submitted') || title.contains('applied') || title.contains('pending')) return AppColors.warning;

    if (t.contains('leave') || title.contains('leave')) return AppColors.primary;
    if (t.contains('tour') || title.contains('tour')) return const Color(0xFF06B6D4);
    
    return AppColors.textSecondary;
  }

  IconData get _icon {
    final t = notif.type.toLowerCase();
    final title = notif.title.toLowerCase();

    if (t.contains('tour') || title.contains('tour')) return Icons.flight_takeoff_rounded;
    if (t.contains('leave') || title.contains('leave')) return Icons.event_available_rounded;
    if (t.contains('payslip') || title.contains('payslip')) return Icons.receipt_long_rounded;

    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? AppColors.backgroundSecondary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? AppColors.cardBorder : AppColors.primary.withOpacity(0.2),
          ),
          boxShadow: notif.isRead
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.timestamp),
                    style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd-MM-yyyy HH:mm').format(dt);
  }
}
