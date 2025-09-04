import 'package:flutter/material.dart';

class CustomOutlineButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool? disabled;

  const CustomOutlineButton({
    super.key,
    required this.onPressed,
    this.text = 'Log out',
    this.textColor = const Color(0xFFFF2050),
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFFF2050),
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = 22.0,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.w500,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding!,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: disabled ?? false ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            foregroundColor: textColor,
            backgroundColor: backgroundColor,
            side: BorderSide(color: borderColor!),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius!),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1,
              color: disabled ?? false ? Colors.grey : textColor,
            ),
          ),
        ),
      ),
    );
  }
}
