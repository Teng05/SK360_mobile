import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryRed = Color(0xFFE63946);
  static const Color darkGray = Color(0xFF2D3436);
  static const Color lightGrayBg = Color(0xFFF8F9FA);
  static const Color softPink = Color(0xFFFDF1F3);
  static const Color borderPink = Color(0xFFE8BCC5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF95A5A6);
  static const Color buttonGray = Color(0xFF95A5A6);
}

class AppHeader extends StatelessWidget {
  final String appName;
  final String subtitle;

  const AppHeader({
    super.key,
    this.appName = 'SK 360°',
    this.subtitle = 'Youth Governance Platform',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryRed,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primaryRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppInputField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool isPassword;
  final bool hasIcon;
  final IconData? iconData;
  final TextInputType keyboardType;

  const AppInputField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.isPassword = false,
    this.hasIcon = false,
    this.iconData,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: AppColors.lightText,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.softPink,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.borderPink,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.borderPink,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryRed,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: widget.isPassword
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                      child: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.lightText,
                        size: 20,
                      ),
                    ),
                  )
                : (widget.hasIcon
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            widget.iconData,
                            color: AppColors.lightText,
                            size: 20,
                          ),
                        )
                      : null),
          ),
        ),
      ],
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final double width;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.width = double.infinity,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? AppColors.primaryRed
              : AppColors.buttonGray,
          foregroundColor: AppColors.white,
          elevation: isPrimary ? 4 : 2,
          shadowColor: isPrimary
              ? AppColors.primaryRed.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class AppCheckboxAgreement extends StatefulWidget {
  final bool isChecked;
  final ValueChanged<bool> onChanged;
  final String text;

  const AppCheckboxAgreement({
    super.key,
    required this.isChecked,
    required this.onChanged,
    required this.text,
  });

  @override
  State<AppCheckboxAgreement> createState() => _AppCheckboxAgreementState();
}

class _AppCheckboxAgreementState extends State<AppCheckboxAgreement> {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            widget.onChanged(!widget.isChecked);
          },
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.isChecked
                    ? AppColors.primaryRed
                    : AppColors.borderPink,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
              color: widget.isChecked ? AppColors.primaryRed : AppColors.white,
            ),
            child: widget.isChecked
                ? const Icon(Icons.check, size: 16, color: AppColors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              widget.onChanged(!widget.isChecked);
            },
            child: Text(
              widget.text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.darkGray,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
