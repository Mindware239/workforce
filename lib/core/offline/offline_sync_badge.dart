import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// OfflineSyncBadge is kept invisible as syncing happens automatically in the background.
class OfflineSyncBadge extends ConsumerWidget {
  final bool compact;

  const OfflineSyncBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
