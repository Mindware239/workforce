import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/operations/presentation/ops_ui.dart';
import 'package:workforce/features/warehouse/providers/warehouse_provider.dart';

/// The four things a scan can lead to: move stock, walk a pick sheet,
/// receive a transfer, count a sheet. Each mirrors its web panel.

const _receivable = ['DISPATCHED', 'IN_TRANSIT', 'PARTIALLY_RECEIVED'];

TextStyle _strong([double size = 13]) => GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: AppColors.textColor,
    );

TextStyle _muted([double size = 11]) =>
    GoogleFonts.inter(fontSize: size, color: AppColors.mutedColor);

const _qtyKeyboard = TextInputType.numberWithOptions(decimal: true);

/// A bordered list of line rows, as the web's `divide-y` lists.
class _LineList extends StatelessWidget {
  final List<Widget> children;

  const _LineList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: i == children.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.borderColor),
                      ),
              ),
              child: children[i],
            ),
        ],
      ),
    );
  }
}

Widget _loading() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );

Widget _statusLine(String status, ChipTone tone, String text) {
  return Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      StatusChip(label: humanStatus(status), tone: tone),
      Text(text, style: _muted(12)),
    ],
  );
}

String _batchSuffix(WidgetRef ref, dynamic batchNumber) {
  final batch = batchNumber?.toString();

  return batch == null || batch.isEmpty
      ? ''
      : ' · ${ref.tr('ops.batch')} $batch';
}

String _placeOf(dynamic warehouse, dynamic location) {
  final path = location?.toString();

  return '${warehouse ?? ''}${path != null && path.isNotEmpty ? ' › $path' : ''}';
}

/// A controller per line, created with its default text the first time.
TextEditingController _controllerFor(
  Map<int, TextEditingController> controllers,
  int id,
  String initial,
) {
  return controllers.putIfAbsent(
    id,
    () => TextEditingController(text: initial),
  );
}

String _qtyText(num value) => formatQty(value).replaceAll(',', '');

// ============================================================================
// STOCK — move what a scan found
// ============================================================================

class StockPanel extends ConsumerStatefulWidget {
  final Map<String, dynamic> hit;
  final VoidCallback onChanged;

  const StockPanel({super.key, required this.hit, required this.onChanged});

  @override
  ConsumerState<StockPanel> createState() => _StockPanelState();
}

class _StockPanelState extends ConsumerState<StockPanel> {
  late List<Map<String, dynamic>> _rows = asMapList(widget.hit['stock']);

  Future<void> _move(Map<String, dynamic> row) async {
    final batch = row['batchNumber']?.toString();

    final moved = await showOpsSheet<bool>(
      context,
      title: ref.tr('wh.moveTitle'),
      description: '${row['productName'] ?? ''} · ${row['variantName'] ?? ''}'
          '${batch != null && batch.isNotEmpty ? ' · $batch' : ''}',
      builder: (_) => _MoveForm(row: row),
    );

    if (moved != true || !mounted) return;

    showFeatureSnack(context, ref.tr('wh.moved'));
    widget.onChanged();

    // Re-read what is here now; the panel keeps its last state if that fails.
    try {
      final again = await ref
          .read(warehouseRepositoryProvider)
          .resolve(widget.hit['code']?.toString() ?? '');

      if (mounted) setState(() => _rows = asMapList(again['stock']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final onHand = widget.hit['onHand'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onHand != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${ref.tr('ops.onHand')}: ', style: _muted(13)),
              Text(
                formatQty(onHand, widget.hit['unitCode']?.toString()),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_rows.isEmpty)
          Text(ref.tr('wh.noStockHere'), style: _muted(13))
        else
          _LineList(
            children: [
              for (final r in _rows) _stockRow(r),
            ],
          ),
      ],
    );
  }

  Widget _stockRow(Map<String, dynamic> r) {
    final (label, tone) = stockStatus(ref, r['status']?.toString());
    final reserved = toNum(r['reservedQuantity']) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: r['productName']?.toString() ?? '',
            style: _strong(),
            children: [
              TextSpan(
                text: ' · ${r['variantName'] ?? ''}',
                style: _muted(13),
              ),
            ],
          ),
        ),
        Text(
          '${_placeOf(r['warehouseName'], r['locationPath'])}'
          '${_batchSuffix(ref, r['batchNumber'])}',
          style: _muted(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            StatusChip(label: label, tone: tone),
            const SizedBox(width: 8),
            Text(
              formatQty(r['quantity'], r['unitCode']?.toString()),
              style: _strong(14),
            ),
            if (reserved > 0) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '(${fill(ref.tr('wh.heldN'), {'value': formatQty(reserved)})})',
                  style: _muted(),
                ),
              ),
            ],
            const Spacer(),
            OutlinedButton(
              onPressed: () => _move(r),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(ref.tr('wh.move')),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoveForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> row;

  const _MoveForm({required this.row});

  @override
  ConsumerState<_MoveForm> createState() => _MoveFormState();
}

class _MoveFormState extends ConsumerState<_MoveForm> {
  late final TextEditingController _quantity = TextEditingController(
    text: _qtyText(toNum(widget.row['quantity']) ?? 0),
  );
  int? _toLocationId;
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  int? get _fromLocationId => toInt(widget.row['locationId']);
  num get _available => toNum(widget.row['quantity']) ?? 0;

  bool get _invalid {
    final q = parseQty(_quantity.text);

    return q == null || !(q > 0) || q > _available || _toLocationId == _fromLocationId;
  }

  Future<void> _save() async {
    final row = widget.row;

    setState(() => _saving = true);

    try {
      await ref.read(warehouseRepositoryProvider).relocate(
        warehouseId: toInt(row['warehouseId']) ?? 0,
        line: {
          'variantId': toInt(row['variantId']),
          'quantity': parseQty(_quantity.text),
          'batchId': toInt(row['batchId']),
          'serialId': toInt(row['serialId']),
          'fromLocationId': _fromLocationId,
          'toLocationId': _toLocationId,
          'status': row['status'],
        },
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);
      showFeatureSnack(context, cleanErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final warehouseId = toInt(row['warehouseId']) ?? 0;
    final locations = (ref.watch(warehouseLocationsProvider(warehouseId))
                .valueOrNull ??
            const <Map<String, dynamic>>[])
        .where(
          (l) => l['isActive'] != false && toInt(l['id']) != _fromLocationId,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: '${ref.tr('wh.from')}: ',
            style: _muted(13),
            children: [
              TextSpan(
                text: _placeOf(row['warehouseName'], row['locationPath']),
                style: _strong(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          initialValue: _toLocationId,
          isExpanded: true,
          decoration: featureInputDecoration(ref.tr('wh.to')),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(ref.tr('ops.noLocation')),
            ),
            for (final l in locations)
              DropdownMenuItem<int?>(
                value: toInt(l['id']),
                child: Text(
                  l['path']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _toLocationId = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantity,
          keyboardType: _qtyKeyboard,
          onChanged: (_) => setState(() {}),
          decoration: featureInputDecoration(ref.tr('ops.quantity')).copyWith(
            helperText: fill(ref.tr('wh.ofOnHand'), {
              'value': formatQty(_available, row['unitCode']?.toString()),
            }),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(ref.tr('common.cancel')),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saving || _invalid ? null : _save,
              icon: _saving
                  ? const ButtonSpinner()
                  : const Icon(Icons.swap_horiz, size: 18),
              label: Text(ref.tr('wh.move')),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// PICK — walk the sheet, tap what you took
// ============================================================================

class PickPanel extends ConsumerStatefulWidget {
  final int id;
  final VoidCallback onChanged;

  const PickPanel({super.key, required this.id, required this.onChanged});

  @override
  ConsumerState<PickPanel> createState() => _PickPanelState();
}

class _PickPanelState extends ConsumerState<PickPanel> {
  final Map<int, TextEditingController> _picked = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _picked.values) {
      c.dispose();
    }
    super.dispose();
  }

  num _left(Map<String, dynamic> i) =>
      (toNum(i['requestedQuantity']) ?? 0) - (toNum(i['pickedQuantity']) ?? 0);

  List<Map<String, dynamic>> _openLines(Map<String, dynamic> pl) {
    return asMapList(pl['items'])
        .where(
          (i) =>
              !const ['PICKED', 'SHORT', 'CANCELLED']
                  .contains(i['status']?.toString()) &&
              _left(i) > 0,
        )
        .toList();
  }

  Future<void> _confirm(List<Map<String, dynamic>> lines) async {
    setState(() => _saving = true);

    try {
      final result = await ref.read(warehouseRepositoryProvider).recordPick(
            widget.id,
            [
              for (final i in lines)
                {
                  'itemId': toInt(i['id']),
                  'pickedQuantity': parseQty(
                        _controllerFor(
                          _picked,
                          toInt(i['id']) ?? 0,
                          _qtyText(_left(i)),
                        ).text,
                      ) ??
                      0,
                },
            ],
          );

      if (!mounted) return;

      showFeatureSnack(
        context,
        ref.tr(
          result['status'] == 'PICKED' ? 'wh.pickedAll' : 'wh.pickedSome',
        ),
      );

      for (final c in _picked.values) {
        c.dispose();
      }
      _picked.clear();

      ref.invalidate(pickListProvider(widget.id));
      widget.onChanged();
    } catch (e) {
      if (mounted) showFeatureSnack(context, cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pickListProvider(widget.id));

    return async.when(
      loading: _loading,
      error: (e, _) => ErrorBanner(cleanErrorMessage(e)),
      data: (pl) {
        final status = pl['status']?.toString() ?? '';
        final lines = _openLines(pl);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusLine(
              status,
              status == 'PICKED' ? ChipTone.success : ChipTone.info,
              '${pl['customerName'] ?? ''} · ${pl['orderNumber'] ?? ''}',
            ),
            const SizedBox(height: 10),
            if (lines.isEmpty)
              NoteBanner(ref.tr('wh.nothingLeftToPick'), tone: NoteTone.success)
            else ...[
              _LineList(
                children: [
                  for (final i in lines) _pickLine(i),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _confirm(lines),
                icon: _saving
                    ? const ButtonSpinner()
                    : const Icon(Icons.assignment_turned_in_outlined, size: 18),
                label: Text(ref.tr('wh.confirmPicks')),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _pickLine(Map<String, dynamic> i) {
    final left = _left(i);
    final unit = i['unitCode']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: i['productName']?.toString() ?? '',
            style: _strong(),
            children: [
              TextSpan(text: ' · ${i['variantName'] ?? ''}', style: _muted(13)),
            ],
          ),
        ),
        Text(
          '${_placeOf(i['warehouseName'], i['locationPath'])}'
          '${_batchSuffix(ref, i['batchNumber'])}',
          style: _muted(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                fill(ref.tr('wh.take'), {'value': formatQty(left, unit)}),
                style: _muted(13),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _controllerFor(
                  _picked,
                  toInt(i['id']) ?? 0,
                  _qtyText(left),
                ),
                keyboardType: _qtyKeyboard,
                decoration: featureInputDecoration(ref.tr('wh.picked')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// RECEIVE — good goes to a bin, damaged is booked as such
// ============================================================================

class TransferPanel extends ConsumerStatefulWidget {
  final int id;
  final VoidCallback onChanged;

  const TransferPanel({super.key, required this.id, required this.onChanged});

  @override
  ConsumerState<TransferPanel> createState() => _TransferPanelState();
}

class _TransferPanelState extends ConsumerState<TransferPanel> {
  final Map<int, TextEditingController> _good = {};
  final Map<int, TextEditingController> _damaged = {};
  int? _locationId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [..._good.values, ..._damaged.values]) {
      c.dispose();
    }
    super.dispose();
  }

  num _left(Map<String, dynamic> i) =>
      (toNum(i['dispatchedQuantity']) ?? 0) -
      (toNum(i['receivedQuantity']) ?? 0) -
      (toNum(i['damagedQuantity']) ?? 0);

  TextEditingController _goodFor(Map<String, dynamic> i) =>
      _controllerFor(_good, toInt(i['id']) ?? 0, _qtyText(_left(i)));

  TextEditingController _damagedFor(Map<String, dynamic> i) =>
      _controllerFor(_damaged, toInt(i['id']) ?? 0, '0');

  Future<void> _receive(List<Map<String, dynamic>> pending) async {
    setState(() => _saving = true);

    try {
      final result = await ref.read(warehouseRepositoryProvider).receiveTransfer(
        widget.id,
        [
          for (final i in pending)
            {
              'itemId': toInt(i['id']),
              'quantity': parseQty(_goodFor(i).text) ?? 0,
              'damagedQuantity': parseQty(_damagedFor(i).text) ?? 0,
              'destLocationId': _locationId,
            },
        ],
      );

      if (!mounted) return;

      showFeatureSnack(
        context,
        ref.tr(
          result['status'] == 'RECEIVED'
              ? 'wh.transferReceived'
              : 'wh.transferPartlyReceived',
        ),
      );

      for (final c in [..._good.values, ..._damaged.values]) {
        c.dispose();
      }
      _good.clear();
      _damaged.clear();

      ref.invalidate(transferDetailProvider(widget.id));
      widget.onChanged();
    } catch (e) {
      if (mounted) showFeatureSnack(context, cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transferDetailProvider(widget.id));

    return async.when(
      loading: _loading,
      error: (e, _) => ErrorBanner(cleanErrorMessage(e)),
      data: (tr) {
        final status = tr['status']?.toString() ?? '';
        final receivable = _receivable.contains(status);
        final destWarehouseId = toInt(tr['destWarehouseId']) ?? 0;
        final pending =
            asMapList(tr['items']).where((i) => _left(i) > 0).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusLine(
              status,
              status == 'RECEIVED'
                  ? ChipTone.success
                  : receivable
                      ? ChipTone.warning
                      : ChipTone.info,
              '${tr['sourceWarehouseName'] ?? ''} → ${tr['destWarehouseName'] ?? ''}',
            ),
            if (!receivable) ...[
              const SizedBox(height: 10),
              NoteBanner(ref.tr('wh.transferNotReceivable')),
            ],
            if (receivable && pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildLocationPicker(destWarehouseId),
              _buildSuggestion(destWarehouseId, pending.first),
              const SizedBox(height: 12),
              _LineList(
                children: [
                  for (final i in pending) _receiveLine(i),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _receive(pending),
                icon: _saving
                    ? const ButtonSpinner()
                    : const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(ref.tr('wh.receive')),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLocationPicker(int warehouseId) {
    final locations = (ref.watch(warehouseLocationsProvider(warehouseId))
                .valueOrNull ??
            const <Map<String, dynamic>>[])
        .where((l) => l['isActive'] != false)
        .toList();

    // A chosen bin that is not in the list (yet) would break the dropdown.
    final value = locations.any((l) => toInt(l['id']) == _locationId)
        ? _locationId
        : null;

    return DropdownButtonFormField<int?>(
      key: ValueKey('putaway-$value-${locations.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: featureInputDecoration(ref.tr('wh.putAwayTo')),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(ref.tr('ops.noLocation')),
        ),
        for (final l in locations)
          DropdownMenuItem<int?>(
            value: toInt(l['id']),
            child: Text(
              l['path']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => _locationId = v),
    );
  }

  /// The bin the put-away rules would choose for the first line; take it or
  /// override it.
  Widget _buildSuggestion(int warehouseId, Map<String, dynamic> first) {
    final variantId = toInt(first['variantId']);

    if (variantId == null) return const SizedBox.shrink();

    final suggestion = ref
        .watch(
          putawaySuggestionProvider(
            PutawayQuery(
              warehouseId: warehouseId,
              variantId: variantId,
              batchId: toInt(first['batchId']),
              quantity: _left(first),
            ),
          ),
        )
        .valueOrNull;

    final suggestedId = toInt(suggestion?['locationId']);

    if (suggestion == null || suggestedId == null || suggestedId == _locationId) {
      return const SizedBox.shrink();
    }

    final rule = asMap(suggestion['rule']);
    final ruleName = rule['name']?.toString();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.saffronTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _locationId = suggestedId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.saffronLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fill(ref.tr('wh.suggestedBin'), {
                          'path': suggestion['path']?.toString() ?? '',
                        }),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.saffronText,
                        ),
                      ),
                      Text(
                        ruleName ?? ref.tr('wh.suggestedByDefault'),
                        style: _muted(),
                      ),
                    ],
                  ),
                ),
                Text(
                  ref.tr('wh.useIt'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.saffronDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiveLine(Map<String, dynamic> i) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: i['productName']?.toString() ?? '',
            style: _strong(),
            children: [
              TextSpan(text: ' · ${i['variantName'] ?? ''}', style: _muted(13)),
            ],
          ),
        ),
        Text(
          '${fill(ref.tr('wh.expected'), {'value': formatQty(_left(i), i['unitCode']?.toString())})}'
          '${_batchSuffix(ref, i['batchNumber'])}',
          style: _muted(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _goodFor(i),
                keyboardType: _qtyKeyboard,
                decoration: featureInputDecoration(ref.tr('wh.good')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _damagedFor(i),
                keyboardType: _qtyKeyboard,
                decoration: featureInputDecoration(ref.tr('wh.damaged')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// COUNT — count what is in front of you
// ============================================================================

class CountPanel extends ConsumerStatefulWidget {
  final int id;
  final VoidCallback onChanged;

  const CountPanel({super.key, required this.id, required this.onChanged});

  @override
  ConsumerState<CountPanel> createState() => _CountPanelState();
}

class _CountPanelState extends ConsumerState<CountPanel> {
  final Map<int, TextEditingController> _counted = {};
  bool _saving = false;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _counted.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<MapEntry<int, String>> get _dirty => _counted.entries
      .map((e) => MapEntry(e.key, e.value.text.trim()))
      .where((e) => e.value.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final dirty = _dirty;

    setState(() => _saving = true);

    try {
      await ref.read(warehouseRepositoryProvider).recordCount(widget.id, [
        for (final e in dirty)
          {'itemId': e.key, 'countedQuantity': parseQty(e.value) ?? 0},
      ]);

      if (!mounted) return;

      showFeatureSnack(
        context,
        fill(ref.tr('wh.countSaved'), {'n': dirty.length}),
      );

      for (final c in _counted.values) {
        c.clear();
      }

      ref.invalidate(countDetailProvider(widget.id));
      widget.onChanged();
    } catch (e) {
      if (mounted) showFeatureSnack(context, cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final result =
          await ref.read(warehouseRepositoryProvider).submitCount(widget.id);

      if (!mounted) return;

      showFeatureSnack(
        context,
        fill(
          ref.tr(
            result['status'] == 'APPLIED'
                ? 'wh.countApplied'
                : 'wh.countSentForApproval',
          ),
          {'n': result['varianceLines'] ?? 0},
        ),
      );

      ref.invalidate(countDetailProvider(widget.id));
      widget.onChanged();
    } catch (e) {
      if (mounted) showFeatureSnack(context, cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(countDetailProvider(widget.id));

    return async.when(
      loading: _loading,
      error: (e, _) => ErrorBanner(cleanErrorMessage(e)),
      data: (c) {
        final status = c['status']?.toString() ?? '';
        final editable = const ['DRAFT', 'IN_PROGRESS'].contains(status);
        final items = asMapList(c['items']);
        final remaining =
            items.where((i) => i['countedQuantity'] == null).length;
        final dirtyCount = _dirty.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusLine(
              status,
              editable ? ChipTone.info : ChipTone.neutral,
              '${c['warehouseName'] ?? ''}'
              '${c['isBlind'] == true ? ' · ${ref.tr('wh.blindCount')}' : ''}'
              ' · ${fill(ref.tr('wh.linesLeft'), {'n': remaining})}',
            ),
            if (!editable) ...[
              const SizedBox(height: 10),
              NoteBanner(ref.tr('wh.countClosed')),
            ],
            const SizedBox(height: 10),
            if (items.isNotEmpty)
              _LineList(
                children: [
                  for (final i in items) _countLine(i, editable),
                ],
              ),
            if (editable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving || dirtyCount == 0 ? null : _save,
                      child: _saving
                          ? const ButtonSpinner(color: AppColors.saffronText)
                          : Text(ref.tr('wh.saveCounts')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _submitting || dirtyCount > 0 ? null : _submit,
                      icon: _submitting
                          ? const ButtonSpinner()
                          : const Icon(Icons.fact_check_outlined, size: 18),
                      label: Text(ref.tr('wh.submitCount')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _countLine(Map<String, dynamic> i, bool editable) {
    final unit = i['unitCode']?.toString();
    final location = i['locationPath']?.toString();
    final expected = i['expectedQuantity'];
    final counted = i['countedQuantity'];
    final id = toInt(i['id']) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: i['productName']?.toString() ?? '',
            style: _strong(),
            children: [
              TextSpan(text: ' · ${i['variantName'] ?? ''}', style: _muted(13)),
            ],
          ),
        ),
        Text(
          '${location == null || location.isEmpty ? ref.tr('ops.noLocation') : location}'
          '${_batchSuffix(ref, i['batchNumber'])}'
          '${expected != null ? ' · ${ref.tr('wh.expectedLabel')} ${formatQty(expected, unit)}' : ''}',
          style: _muted(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                counted != null
                    ? fill(ref.tr('wh.countedValue'), {
                        'value': formatQty(counted, unit),
                      })
                    : ref.tr('wh.notCountedYet'),
                style: _muted(13),
              ),
            ),
            if (editable)
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _controllerFor(_counted, id, ''),
                  keyboardType: _qtyKeyboard,
                  onChanged: (_) => setState(() {}),
                  decoration: featureInputDecoration(
                    ref.tr('wh.count'),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
