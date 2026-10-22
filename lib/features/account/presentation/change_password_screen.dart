import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/realtime/realtime_service.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

import '../providers/account_provider.dart';

/// Settings → Security: change the password (PATCH /auth/password). The
/// server signs every other device out and returns a fresh token for this
/// one, which is stored so the app stays signed in.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = await ref.read(accountRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );

      if (token != null) {
        await ref.read(secureStorageProvider).saveToken(token);
        // The server signs the old token's sockets out; reopen with the new one.
        unawaited(RealtimeService.instance.reconnect());
      }

      if (!mounted) return;

      showFeatureSnack(context, ref.tr('setx.passwordChanged'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = cleanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('setx.changePassword')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FeatureHeading(
                title: ref.tr('setx.changePassword'),
                subtitle: ref.tr('setx.changePasswordHint'),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: featureInputDecoration(
                  ref.tr('setx.currentPassword'),
                  suffixIcon: toggle,
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? ref.tr('setx.currentRequired')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                decoration: featureInputDecoration(ref.tr('setx.newPassword')),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return ref.tr('setx.passwordMin');
                  }

                  if (value == _current.text) {
                    return ref.tr('setx.passwordSame');
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration:
                    featureInputDecoration(ref.tr('setx.confirmPassword')),
                validator: (value) => value != _next.text
                    ? ref.tr('setx.passwordMismatch')
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                ref.tr('setx.otherDevicesNote'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedColor,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(ref.tr('setx.updatePassword')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
