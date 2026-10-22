import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

import '../providers/account_provider.dart';

/// "Delete my account" for a signed-in person. It only asks: the account
/// belongs to the organization that created it, so an admin or the owner (or
/// the platform, for an owner) approves before anything is deleted. Shows the
/// latest request and lets a pending one be withdrawn — the same flow as the
/// web settings card (POST/GET/DELETE /account-deletion/me).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() => ref.read(accountDeletionProvider.notifier).load());
  }

  Future<void> _request() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RequestDialog(),
    );

    if (reason == null || !mounted) return;

    final error =
        await ref.read(accountDeletionProvider.notifier).request(reason);

    if (!mounted) return;

    showFeatureSnack(context, error ?? ref.tr('delx.sent'));
  }

  Future<void> _withdraw() async {
    final error = await ref.read(accountDeletionProvider.notifier).cancel();

    if (!mounted) return;

    showFeatureSnack(context, error ?? ref.tr('delx.withdrawn'));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountDeletionProvider);
    final request = state.request;

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('delx.cardTitle')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(accountDeletionProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FeatureHeading(
                title: ref.tr('delx.cardTitle'),
                subtitle: ref.tr('delx.cardBody'),
              ),
              const SizedBox(height: 16),
              if (state.error != null) ...[
                ErrorBanner(state.error!),
                const SizedBox(height: 12),
              ],
              if (state.isPending && request != null) ...[
                _Notice(
                  tone: ChipTone.warning,
                  text:
                      '${fill(ref.tr('delx.pendingSince'), {'date': formatApiDate(request['createdAt'])})} '
                      '${ref.tr('delx.approver_${request['approver'] ?? 'organization'}')}',
                ),
                const SizedBox(height: 12),
              ],
              if (request?['status'] == 'rejected') ...[
                _Notice(
                  tone: ChipTone.danger,
                  text:
                      '${fill(ref.tr('delx.rejectedOn'), {'date': formatApiDate(request!['decidedAt'])})}'
                      '${(request['decisionNote']?.toString().isNotEmpty ?? false) ? ' — ${request['decisionNote']}' : ''}',
                ),
                const SizedBox(height: 12),
              ],
              FeatureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(ref.tr('delx.deletedTitle')),
                    const SizedBox(height: 6),
                    _Bullet(ref.tr('delx.whatGoes')),
                    const SizedBox(height: 12),
                    SectionTitle(ref.tr('delx.keptTitle')),
                    const SizedBox(height: 6),
                    _Bullet(ref.tr('delx.whatStays')),
                    const SizedBox(height: 12),
                    Text(
                      ref.tr('delx.timeline'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (state.isLoading && request == null)
                const Center(child: CircularProgressIndicator())
              else if (state.isPending)
                OutlinedButton(
                  onPressed: state.isSubmitting ? null : _withdraw,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(ref.tr('delx.withdraw')),
                )
              else
                ElevatedButton.icon(
                  onPressed: state.isSubmitting ? null : _request,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: AppColors.white,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(ref.tr('delx.requestButton')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final ChipTone tone;
  final String text;

  const _Notice({required this.tone, required this.text});

  @override
  Widget build(BuildContext context) {
    final danger = tone == ChipTone.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFDECEC) : AppColors.saffronTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger ? const Color(0xFFF5C2C0) : AppColors.saffronLight,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.4,
          color: danger ? const Color(0xFFB3261E) : AppColors.saffronText,
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.mutedColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Confirmation with an optional reason. Pops the reason ('' when none), or
/// null when cancelled.
class _RequestDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends ConsumerState<_RequestDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        ref.tr('delx.confirmTitle'),
        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('delx.confirmBody'),
              style: GoogleFonts.inter(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 2000,
              minLines: 2,
              maxLines: 4,
              decoration: featureInputDecoration(ref.tr('delx.reasonOptional')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ref.tr('common.cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: AppColors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(ref.tr('delx.confirmSend')),
        ),
      ],
    );
  }
}
