import 'package:flutter/material.dart';

import 'package:workforce/features/mdm/services/mdm_service.dart';

/// Shown once at install, before management takes effect. Google Play and most
/// privacy regimes require clear, affirmative consent before an employer app
/// may manage a device, track location, or monitor calls. The server will not
/// issue any device command until this consent is recorded.
class MdmConsentScreen extends StatefulWidget {
  const MdmConsentScreen({super.key, required this.onDone});

  /// Called after consent is recorded (or declined) so the app can continue.
  final VoidCallback onDone;

  @override
  State<MdmConsentScreen> createState() => _MdmConsentScreenState();
}

class _MdmConsentScreenState extends State<MdmConsentScreen> {
  bool _submitting = false;

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      await MdmService().recordConsent();
    } finally {
      if (mounted) widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Company-managed device',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'This is a work device managed by your employer. While you are '
                'signed in, the app may:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const _Bullet('Track your location during working hours.'),
              const _Bullet('Report when location is switched off.'),
              const _Bullet('Let your administrator lock or, if the device is '
                  'lost, erase this work device.'),
              const _Bullet('Prevent this work app from being uninstalled.'),
              const SizedBox(height: 16),
              Text(
                'Management applies only to this work device and your work '
                'account. You can review your employer\'s policy at any time.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _accept,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('I understand and agree'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting ? null : widget.onDone,
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 6),
          ),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
