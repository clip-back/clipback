// Frozen adapter: only the AFTER build imports the newly added screen.
// Its explicit [] scene is a standalone widget, never a claimed API empty result.
import 'package:clipback_frontend/features/home/notification_list_screen.dart';
import 'notification_alignment_preview.dart' as preview;

Future<void> main() => preview.startNotificationPreview(
  emptyBuilder: (onBack, onOpenSettings) => NotificationListScreen(
    items: const [],
    onBack: onBack,
    onOpenSettings: onOpenSettings,
  ),
);
