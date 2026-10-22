/// A finished call in the thread, on the caller's side like a message would
/// be: outgoing on the right for the person who rang, incoming on the left
/// for the one who was rung. Tapping it calls back with the same media.
/// Mirrors CallEntry in frontend/src/components/chat/chat-view.tsx.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/call/data/call_models.dart';
import 'package:workforce/features/call/presentation/call_screen.dart';

const _missedRed = Color(0xFFC62828);

class CallEntry extends ConsumerWidget {
  const CallEntry({
    super.key,
    required this.call,
    required this.mine,
    required this.time,
    this.onCallBack,
  });

  final CallRecord call;

  /// This person placed the call.
  final bool mine;

  /// Time of day, formatted like the messages around it.
  final String time;
  final VoidCallback? onCallBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = call.media == CallMedia.video;
    final connected = call.status == 'ended' || call.answeredAt != null;
    // Rung and never picked up: missed, from where the callee sits.
    final missedByMe = !mine && !connected && (call.status == 'missed' || call.status == 'cancelled');

    final title = missedByMe
        ? ref.tr(video ? 'chat.callMissedVideo' : 'chat.callMissedAudio')
        : mine
            ? ref.tr(video ? 'chat.callOutgoingVideo' : 'chat.callOutgoingAudio')
            : ref.tr(video ? 'chat.callIncomingVideo' : 'chat.callIncomingAudio');

    final String detail;
    if (connected) {
      detail = call.durationSeconds != null ? formatCallDuration(call.durationSeconds!) : '';
    } else if (call.status == 'rejected') {
      detail = ref.tr('chat.callDeclined');
    } else if (call.status == 'missed') {
      detail = mine ? ref.tr(call.endReason == 'busy' ? 'chat.callBusy' : 'chat.callNoAnswer') : '';
    } else if (call.status == 'cancelled') {
      detail = mine ? ref.tr('chat.callCancelled') : '';
    } else {
      detail = ref.tr('chat.callNotConnected');
    }

    final icon = missedByMe
        ? Icons.phone_missed_rounded
        : video
            ? Icons.videocam_rounded
            : mine
                ? Icons.call_made_rounded
                : Icons.call_received_rounded;
    final sub = [detail, time].where((s) => s.isNotEmpty).join(' · ');
    final accent = missedByMe ? _missedRed : AppColors.saffronText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Semantics(
            button: onCallBack != null,
            label: [title, sub].where((s) => s.isNotEmpty).join(' · '),
            hint: onCallBack != null ? ref.tr('chat.callBack') : null,
            excludeSemantics: true,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderColor),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onCallBack,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: missedByMe ? const Color(0xFFFDECEA) : AppColors.saffronTint,
                        ),
                        child: Icon(icon, size: 16, color: accent),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: missedByMe ? _missedRed : AppColors.textColor,
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              sub,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
