import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workforce/core/location/navigation_launcher.dart';
import 'package:workforce/core/styles/app_colors.dart';
import '../providers/customer_visits_provider.dart';

class CustomerVisitsView extends ConsumerStatefulWidget {
  const CustomerVisitsView({super.key});

  @override
  ConsumerState<CustomerVisitsView> createState() => _CustomerVisitsViewState();
}

class _CustomerVisitsViewState extends ConsumerState<CustomerVisitsView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerVisitsProvider.notifier).loadVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerVisitsProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                onPressed: () => ref.read(customerVisitsProvider.notifier).loadVisits(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.visits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_city_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Customer Visits Assigned',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Assigned customer visits from your manager will appear here with instant turn-by-turn navigation.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(customerVisitsProvider.notifier).loadVisits(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.visits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final visit = state.visits[index];
          return _CustomerVisitCard(visit: visit);
        },
      ),
    );
  }
}

class _CustomerVisitCard extends ConsumerWidget {
  final Map<String, dynamic> visit;

  const _CustomerVisitCard({required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = visit['id'] as int? ?? 0;
    final title = visit['title']?.toString() ?? 'Customer Visit';
    final customerName = visit['customerName']?.toString() ?? 'Client';
    final contactPerson = visit['contactPerson']?.toString();
    final contactPhone = visit['contactPhone']?.toString();
    final address = visit['address']?.toString() ?? 'Client Address';
    final status = visit['status']?.toString() ?? 'assigned';
    final destLat = double.tryParse(visit['destinationLat']?.toString() ?? '') ??
        double.tryParse(visit['destination_lat']?.toString() ?? '') ??
        0.0;
    final destLng = double.tryParse(visit['destinationLng']?.toString() ?? '') ??
        double.tryParse(visit['destination_lng']?.toString() ?? '') ??
        0.0;
    final hasValidCoords = (destLat != 0.0 && destLng != 0.0) &&
        destLat >= -90.0 && destLat <= 90.0 &&
        destLng >= -180.0 && destLng <= 180.0;
    final hasAddress = address.trim().isNotEmpty && address != 'Client Address';
    final canNavigate = hasValidCoords || hasAddress;
    
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Completed';
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusLabel = 'In Progress';
        break;
      default:
        statusColor = Colors.blue;
        statusLabel = 'Assigned';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Address & Contact Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: canNavigate
                      ? () {
                          NavigationLauncher.startTurnByTurnNavigation(
                            destinationLat: destLat,
                            destinationLng: destLng,
                            destinationLabel: customerName,
                            destinationAddress: address,
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: canNavigate ? Colors.blue.shade900 : Colors.grey.shade800,
                              decoration: canNavigate ? TextDecoration.underline : null,
                              decorationColor: Colors.blue.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (contactPerson != null && contactPerson.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        contactPerson,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800),
                      ),
                      if (contactPhone != null && contactPhone.isNotEmpty) ...[
                        const Spacer(),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse('tel:$contactPhone')),
                          child: Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                contactPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons: Navigate & Check-in / Checkout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                // Turn-by-Turn Navigation Button (Google Maps)
                if (canNavigate)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade800,
                        side: BorderSide(color: Colors.blue.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        NavigationLauncher.startTurnByTurnNavigation(
                          destinationLat: destLat,
                          destinationLng: destLng,
                          destinationLabel: customerName,
                          destinationAddress: address,
                        );
                      },
                    ),
                  ),

                if (canNavigate) const SizedBox(width: 10),

                // Check-in or Checkout Button
                if (status == 'assigned')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.pin_drop, size: 16),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.saffronDeep,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final err = await ref
                            .read(customerVisitsProvider.notifier)
                            .checkInVisit(id);
                        if (context.mounted) {
                          if (err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err), backgroundColor: Colors.red),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Checked in successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      },
                    ),
                  )
                else if (status == 'in_progress')
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Check Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showCheckoutDialog(context, ref, id),
                    ),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Visit Completed',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, WidgetRef ref, int visitId) {
    final notesCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Complete Customer Visit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Meeting Outcome / Notes',
                hintText: 'e.g. Discussed requirements, order taken',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Order / Payment Collected (₹)',
                hintText: '0.00',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.saffronDeep),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final err = await ref.read(customerVisitsProvider.notifier).checkOutVisit(
                    visitId,
                    outcomeNotes: notesCtrl.text.trim(),
                    orderAmount: amount,
                  );
              if (context.mounted) {
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Visit marked complete!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('Complete Visit'),
          ),
        ],
      ),
    );
  }
}
