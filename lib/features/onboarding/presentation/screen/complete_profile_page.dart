import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/auth/providers/auth_provider.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({
    super.key,
    this.onSubmit,
    this.initialFullName = 'Employee',
    this.initialMobile = '9999999999',
    this.initialEmail = 'you@company.com',
  });

  final Future<void> Function(Map<String, dynamic> data)? onSubmit;

  final String initialFullName;
  final String initialMobile;
  final String initialEmail;

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;

  final _emergency1ContactController = TextEditingController();

  final _emergency2ContactController = TextEditingController();

  final _permanentAddressController = TextEditingController();

  final _correspondenceAddressController = TextEditingController();

  String? _emergency1Relation;
  String? _emergency2Relation;

  bool _termsAccepted = false;
  bool _isSubmitting = false;

  bool _fullNameEditable = false;
  bool _mobileEditable = false;
  bool _emailEditable = true;

  final List<String> _relations = const [
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Spouse',
    'Son',
    'Daughter',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _fullNameController = TextEditingController(text: widget.initialFullName);

    _mobileController = TextEditingController(text: widget.initialMobile);

    _emailController = TextEditingController(text: widget.initialEmail);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOnboardingData();
    });
  }

  // ----------------------------------------------------------
  // Load onboarding data from AuthState
  // ----------------------------------------------------------

  void _loadOnboardingData() {
    if (!mounted) return;

    final onboarding = ref.read(authProvider).onboardingStatus;

    if (onboarding == null) {
      return;
    }

    final identity = onboarding['identity'] is Map
        ? Map<String, dynamic>.from(onboarding['identity'])
        : <String, dynamic>{};

    final editable = onboarding['editable'] is Map
        ? Map<String, dynamic>.from(onboarding['editable'])
        : <String, dynamic>{};

    final details = onboarding['details'] is Map
        ? Map<String, dynamic>.from(onboarding['details'])
        : <String, dynamic>{};

    setState(() {
      // ------------------------------------------------------
      // Identity
      // ------------------------------------------------------

      final fullName = identity['fullName']?.toString();

      final mobile = identity['mobileNumber']?.toString();

      final email = identity['email']?.toString();

      if (fullName != null && fullName.trim().isNotEmpty) {
        _fullNameController.text = fullName;
      }

      if (mobile != null && mobile.trim().isNotEmpty) {
        _mobileController.text = mobile;
      }

      if (email != null && email.trim().isNotEmpty) {
        _emailController.text = email;
      } else {
        _emailController.clear();
      }

      // ------------------------------------------------------
      // Editable flags
      // ------------------------------------------------------

      _fullNameEditable = editable['fullName'] == true;

      _mobileEditable = editable['mobileNumber'] == true;

      _emailEditable = editable['email'] == true;

      // ------------------------------------------------------
      // Emergency Contact 1
      // ------------------------------------------------------

      final emergency1Relation = details['emergencyContact1Relation']
          ?.toString();

      final emergency1Number = details['emergencyContact1Number']?.toString();

      if (emergency1Relation != null &&
          emergency1Relation.isNotEmpty &&
          _relations.contains(emergency1Relation)) {
        _emergency1Relation = emergency1Relation;
      }

      if (emergency1Number != null) {
        _emergency1ContactController.text = emergency1Number;
      }

      // ------------------------------------------------------
      // Emergency Contact 2
      // ------------------------------------------------------

      final emergency2Relation = details['emergencyContact2Relation']
          ?.toString();

      final emergency2Number = details['emergencyContact2Number']?.toString();

      if (emergency2Relation != null &&
          emergency2Relation.isNotEmpty &&
          _relations.contains(emergency2Relation)) {
        _emergency2Relation = emergency2Relation;
      }

      if (emergency2Number != null) {
        _emergency2ContactController.text = emergency2Number;
      }

      // ------------------------------------------------------
      // Addresses
      // ------------------------------------------------------

      final permanentAddress = details['permanentAddress']?.toString();

      final correspondenceAddress = details['correspondenceAddress']
          ?.toString();

      if (permanentAddress != null) {
        _permanentAddressController.text = permanentAddress;
      }

      if (correspondenceAddress != null) {
        _correspondenceAddressController.text = correspondenceAddress;
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _emergency1ContactController.dispose();
    _emergency2ContactController.dispose();
    _permanentAddressController.dispose();
    _correspondenceAddressController.dispose();

    super.dispose();
  }

  // ----------------------------------------------------------
  // Main
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),

                      const SizedBox(height: 16),

                      _buildYourDetailsCard(),

                      const SizedBox(height: 12),

                      _buildEmergencyCard(
                        title: 'Emergency Contact 1',
                        relation: _emergency1Relation,
                        contactController: _emergency1ContactController,
                        onRelationChanged: (value) {
                          setState(() {
                            _emergency1Relation = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildEmergencyCard(
                        title: 'Emergency Contact 2',
                        relation: _emergency2Relation,
                        contactController: _emergency2ContactController,
                        onRelationChanged: (value) {
                          setState(() {
                            _emergency2Relation = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildAddressCard(),

                      const SizedBox(height: 12),

                      _buildTermsCard(),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Header
  // ----------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete your profile',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Before you continue, please share a few more details '
          'required by your organization.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mutedColor,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Your Details
  // ----------------------------------------------------------

  Widget _buildYourDetailsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('Your Details'),

          const SizedBox(height: 10),

          _buildDivider(),

          const SizedBox(height: 10),

          Text(
            'Details that are organizationally filled in cannot be changed here. Please complete the ones left blank.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.mutedColor,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          _buildLabelWithBadge(label: 'Full Name', badge: 'SET BY ADMIN'),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _fullNameController,
            readOnly: !_fullNameEditable,
            enabled: _fullNameEditable,
          ),

          const SizedBox(height: 12),

          _buildLabelWithBadge(label: 'Mobile Number', badge: 'SET BY ADMIN'),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _mobileController,
            readOnly: !_mobileEditable,
            enabled: _mobileEditable,
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),

          const SizedBox(height: 12),

          _buildFieldLabel('Email'),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _emailController,
            readOnly: !_emailEditable,
            enabled: _emailEditable,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Emergency Contact
  // ----------------------------------------------------------

  Widget _buildEmergencyCard({
    required String title,
    required String? relation,
    required TextEditingController contactController,
    required ValueChanged<String?> onRelationChanged,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(title),

          const SizedBox(height: 10),

          _buildDivider(),

          const SizedBox(height: 13),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildRelationField(
                  relation: relation,
                  onChanged: onRelationChanged,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Contact Number'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: contactController,
                      hintText: '10-digit mobile number',
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) {
                          return 'Required';
                        }

                        if (!RegExp(r'^[0-9]{10}$').hasMatch(text)) {
                          return 'Invalid number';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelationField({
    required String? relation,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Relation'),

        const SizedBox(height: 6),

        DropdownButtonFormField<String>(
          value: relation,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppColors.textColor,
            fontWeight: FontWeight.w400,
          ),
          decoration: _inputDecoration(hintText: 'Select relation'),
          items: _relations
              .map(
                (relation) => DropdownMenuItem<String>(
                  value: relation,
                  child: Text(relation, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }

            return null;
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // Address
  // ----------------------------------------------------------

  Widget _buildAddressCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('Address'),

          const SizedBox(height: 10),

          _buildDivider(),

          const SizedBox(height: 14),

          _buildFieldLabel('Permanent Address'),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _permanentAddressController,
            hintText: 'Enter your address',
            maxLines: 3,
            minLines: 3,
            textInputAction: TextInputAction.newline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Permanent address is required';
              }

              return null;
            },
          ),

          const SizedBox(height: 14),

          _buildFieldLabel('Correspondence Address'),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _correspondenceAddressController,
            hintText: 'Enter your address',
            maxLines: 3,
            minLines: 3,
            textInputAction: TextInputAction.newline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Correspondence address is required';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Terms
  // ----------------------------------------------------------

  Widget _buildTermsCard() {
    return _buildCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: _termsAccepted,
              activeColor: AppColors.primaryFillColor,
              checkColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD2C9CC), width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) {
                setState(() {
                  _termsAccepted = value ?? false;
                });
              },
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.mutedColor,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(
                      text: 'I have read and agree to the organization\'s ',
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: _showTermsSheet,
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.primaryFillColor,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryFillColor,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Terms Bottom Sheet
  // ----------------------------------------------------------

  Future<void> _showTermsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textColor,
                        ),
                      ),
                    ),

                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF777177),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  'Test',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.mutedColor,
                  ),
                ),

                const SizedBox(height: 12),

                Container(height: 1, color: AppColors.borderColor),

                const SizedBox(height: 22),

                Center(
                  child: Text(
                    'Your organization has not published '
                    'any terms yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _termsAccepted = true;
                      });

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryFillColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'I Agree',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // Bottom Submit
  // ----------------------------------------------------------

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryFillColor,
            disabledBackgroundColor: AppColors.primaryFillColor.withOpacity(
              0.5,
            ),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Submit & Continue',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Submit
  // ----------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please accept the Terms & Conditions.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final fullName = _fullNameController.text.trim();

    final mobileNumber = _mobileController.text.trim();

    final email = _emailController.text.trim();

    final emergency1Relation = _emergency1Relation;

    final emergency1Number = _emergency1ContactController.text.trim();

    final emergency2Relation = _emergency2Relation;

    final emergency2Number = _emergency2ContactController.text.trim();

    final permanentAddress = _permanentAddressController.text.trim();

    final correspondenceAddress = _correspondenceAddressController.text.trim();

    final data = <String, dynamic>{
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'email': email,
      'emergencyContact1Relation': emergency1Relation,
      'emergencyContact1Number': emergency1Number,
      'emergencyContact2Relation': emergency2Relation,
      'emergencyContact2Number': emergency2Number,
      'permanentAddress': permanentAddress,
      'correspondenceAddress': correspondenceAddress,
      'termsAccepted': _termsAccepted,
    };

    setState(() {
      _isSubmitting = true;
    });

    try {
      // ------------------------------------------------------
      // Keep existing callback support.
      // ------------------------------------------------------

      if (widget.onSubmit != null) {
        await widget.onSubmit!(data);
      } else {
        // ----------------------------------------------------
        // Actual API submission
        // ----------------------------------------------------

        await ref
            .read(authProvider.notifier)
            .submitOnboarding(
              emergencyContact1Relation: emergency1Relation!,
              emergencyContact1Number: emergency1Number,
              emergencyContact2Relation: emergency2Relation!,
              emergencyContact2Number: emergency2Number,
              permanentAddress: permanentAddress,
              correspondenceAddress: correspondenceAddress,
              termsAccepted: _termsAccepted,
              fullName: _fullNameEditable ? fullName : null,
              mobileNumber: _mobileEditable ? mobileNumber : null,
              email: _emailEditable ? email : null,
            );
      }

      if (!mounted) return;

      // ------------------------------------------------------
      // Successful onboarding
      // ------------------------------------------------------

      context.go(AppRoutes.dashboard);
    } catch (e) {
      if (!mounted) return;

      final authError = ref.read(authProvider).error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authError ?? e.toString(),
            style: GoogleFonts.inter(fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // Reusable UI
  // ----------------------------------------------------------

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1, color: AppColors.borderColor);
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildLabelWithBadge({required String label, required String badge}) {
    return Row(
      children: [
        _buildFieldLabel(label),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryFillColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryFillColor,
              letterSpacing: 0.15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    bool enabled = true,
    bool readOnly = false,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    int? minLines,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: enabled ? AppColors.textColor : AppColors.mutedColor,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: AppColors.primaryFillColor,
      decoration: _inputDecoration(hintText: hintText)
          .copyWith(counterText: ''),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xFFAAA2A6),
      ),
      filled: true,
      fillColor: AppColors.backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.primaryFillColor,
          width: 1,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE57373)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE57373)),
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 9,
        height: 1.1,
        color: const Color(0xFFD64545),
      ),
    );
  }
}
