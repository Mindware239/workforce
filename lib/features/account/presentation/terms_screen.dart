import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/profile/providers/profile_provider.dart';

import '../providers/account_provider.dart';

/// The organization's own terms and conditions (GET /organizations/terms),
/// shown as plain text, as the web employee terms page does.
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(organizationTermsProvider);
    final organizationName =
        ref.watch(profileProvider).profile?['organizationName']?.toString();

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('termsx.title')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(organizationTermsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FeatureHeading(
                title: ref.tr('termsx.title'),
                subtitle: organizationName,
              ),
              const SizedBox(height: 16),
              terms.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => LoadErrorView(
                  message: cleanErrorMessage(error),
                  retryLabel: ref.tr('common.retry'),
                  onRetry: () => ref.invalidate(organizationTermsProvider),
                ),
                data: (data) {
                  final content = data['content']?.toString().trim() ?? '';

                  if (content.isEmpty) {
                    return EmptyNote(
                      ref.tr('termsx.notPublished'),
                      icon: Icons.description_outlined,
                    );
                  }

                  return FeatureCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          content,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.textColor,
                          ),
                        ),
                        if (data['updatedAt'] != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            fill(ref.tr('termsx.lastUpdated'), {
                              'date': formatApiDate(data['updatedAt']),
                            }),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.mutedColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
