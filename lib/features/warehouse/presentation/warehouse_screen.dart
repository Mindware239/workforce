import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/operations/presentation/ops_ui.dart';
import 'package:workforce/features/operations/providers/entitlements_provider.dart';
import 'package:workforce/features/warehouse/presentation/barcode_scanner_screen.dart';
import 'package:workforce/features/warehouse/presentation/warehouse_panels.dart';
import 'package:workforce/features/warehouse/providers/warehouse_provider.dart';

/// The warehouse, from a phone. Scan anything — a roll, a lot, a bin, a pick
/// sheet, a transfer, a count — and do the one thing that scan calls for:
/// move it, pick it, receive it, count it. Mirrors the web page
/// /employee/warehouse; every action is the same ledger write.
class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

/// Scan results that are stock you can move.
const stockTypes = [
  'variant',
  'product',
  'batch',
  'serial',
  'location',
  'warehouse',
];

const Map<String, String> _resolvedTypeKeys = {
  'variant': 'wh.typeVariant',
  'product': 'wh.typeProduct',
  'batch': 'wh.typeBatch',
  'serial': 'wh.typeSerial',
  'location': 'wh.typeLocation',
  'warehouse': 'wh.typeWarehouse',
  'purchase_order': 'wh.typePurchaseOrder',
  'receipt': 'wh.typeReceipt',
  'purchase_return': 'wh.typePurchaseReturn',
  'sales_order': 'wh.typeSalesOrder',
  'pick_list': 'wh.typePickList',
  'dispatch': 'wh.typeDispatch',
  'sales_return': 'wh.typeSalesReturn',
  'invoice': 'wh.typeInvoice',
  'payment': 'wh.typePayment',
  'work_order': 'wh.typeWorkOrder',
  'inspection': 'wh.typeInspection',
  'transfer': 'wh.typeTransfer',
  'adjustment': 'wh.typeAdjustment',
  'count': 'wh.typeCount',
};

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(_load);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    Map<String, bool>? features;

    try {
      features = await ref.read(entitlementsProvider.future);
    } catch (_) {
      features = null;
    }

    if (features != null && features[inventoryFeature] != true) return;

    if (!mounted) return;

    await ref.read(warehouseProvider.notifier).loadOpenWork();
  }

  Future<void> _refresh() async {
    ref.invalidate(entitlementsProvider);

    await _load();
  }

  Future<void> _find([String? value]) async {
    final code = (value ?? _code.text).trim();

    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();

    final found = await ref.read(warehouseProvider.notifier).resolve(code);

    if (found && mounted) _code.clear();
  }

  Future<void> _openCamera() async {
    final value = await BarcodeScannerScreen.scan(context);

    if (value == null || !mounted) return;

    _code.text = value;

    await _find(value);
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(entitlementsProvider);
    final locked = featureLocked(entitlements, inventoryFeature);
    final state = ref.watch(warehouseProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              FeatureHeading(
                title: ref.tr('wh.title'),
                subtitle: ref.tr('wh.subtitle'),
              ),
              const SizedBox(height: 16),
              if (locked)
                FeatureLockedPanel(featureName: ref.tr('wh.featureName'))
              else ...[
                _buildScanBox(state),
                const SizedBox(height: 16),
                if (state.hit != null)
                  _ResultPanel(
                    key: ValueKey('${state.hit!['type']}-${state.hit!['id']}'),
                    hit: state.hit!,
                  )
                else
                  ..._buildOpenWork(state),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanBox(WarehouseState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _find(),
            onChanged: (_) {
              ref.read(warehouseProvider.notifier).clearResolveError();
              setState(() {});
            },
            decoration: featureInputDecoration(
              ref.tr('wh.codeLabel'),
              hint: ref.tr('wh.placeholder'),
            ).copyWith(
              prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
              errorText: state.resolveError,
              errorMaxLines: 3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: state.resolving ? null : _openCamera,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Tooltip(
              message: ref.tr('wh.scanWithCamera'),
              child: const Icon(Icons.photo_camera_outlined),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: state.resolving || _code.text.trim().isEmpty
                ? null
                : () => _find(),
            child: state.resolving
                ? const ButtonSpinner()
                : Text(ref.tr('wh.find')),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOpenWork(WarehouseState state) {
    final notifier = ref.read(warehouseProvider.notifier);

    final work = <_WorkItem>[
      for (final p in state.pickLists)
        _WorkItem(
          icon: Icons.assignment_outlined,
          label: p['pickNumber']?.toString() ?? '',
          sub: '${p['customerName'] ?? ''} · '
              '${formatQty(p['pickedQuantity'])} / ${formatQty(p['requestedQuantity'])}',
          onTap: () => notifier.open(
            type: 'pick_list',
            id: toInt(p['id']) ?? 0,
            label: p['pickNumber']?.toString() ?? '',
            sub: p['orderNumber']?.toString(),
            status: p['status']?.toString(),
          ),
        ),
      for (final t in state.transfers)
        _WorkItem(
          icon: Icons.local_shipping_outlined,
          label: t['transferNumber']?.toString() ?? '',
          sub: '${t['sourceWarehouseName'] ?? ''} → ${t['destWarehouseName'] ?? ''}',
          onTap: () => notifier.open(
            type: 'transfer',
            id: toInt(t['id']) ?? 0,
            label: t['transferNumber']?.toString() ?? '',
            status: t['status']?.toString(),
          ),
        ),
      for (final c in state.counts)
        _WorkItem(
          icon: Icons.fact_check_outlined,
          label: c['countNumber']?.toString() ?? '',
          sub: c['warehouseName']?.toString() ?? '',
          onTap: () => notifier.open(
            type: 'count',
            id: toInt(c['id']) ?? 0,
            label: c['countNumber']?.toString() ?? '',
            sub: c['warehouseName']?.toString(),
            status: c['status']?.toString(),
          ),
        ),
    ];

    return [
      OpsCaption(ref.tr('wh.openWork')),
      const SizedBox(height: 8),
      if (state.loadingWork && work.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (work.isEmpty)
        EmptyNote(ref.tr('wh.nothingOpen'), icon: Icons.qr_code_2_outlined)
      else
        for (final item in work)
          FeatureCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            onTap: item.onTap,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurfaceTintColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: AppColors.primaryFillColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textColor,
                        ),
                      ),
                      Text(
                        item.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.mutedColor),
              ],
            ),
          ),
    ];
  }
}

class _WorkItem {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _WorkItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
}

/// What the scan turned out to be, and the one thing to do with it.
class _ResultPanel extends ConsumerWidget {
  final Map<String, dynamic> hit;

  const _ResultPanel({super.key, required this.hit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = hit['type']?.toString() ?? '';
    final id = toInt(hit['id']) ?? 0;
    final sub = hit['sub']?.toString();
    final status = hit['status']?.toString();
    void changed() => ref.read(warehouseProvider.notifier).loadOpenWork();

    Widget body;

    if (stockTypes.contains(type)) {
      body = StockPanel(hit: hit, onChanged: changed);
    } else if (type == 'pick_list') {
      body = PickPanel(id: id, onChanged: changed);
    } else if (type == 'transfer') {
      body = TransferPanel(id: id, onChanged: changed);
    } else if (type == 'count') {
      body = CountPanel(id: id, onChanged: changed);
    } else {
      body = Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (status != null && status.isNotEmpty)
            StatusChip(label: humanStatus(status), tone: ChipTone.info),
          Text(
            ref.tr('wh.consoleOnly'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        ],
      );
    }

    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OpsCaption(
                      ref.tr(_resolvedTypeKeys[type] ?? 'wh.typeVariant'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hit['label']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedColor,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(warehouseProvider.notifier).closeHit(),
                child: Text(ref.tr('wh.scanAnother')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}
