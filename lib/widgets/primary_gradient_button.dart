import 'package:flutter/material.dart';
import '../../core/font_utils.dart';


class PrimaryGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final IconData? icon;
  const PrimaryGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 42,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFF4A90E2)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, color: Colors.white, size: 18) : const SizedBox.shrink(),
        label: Text(
          text,
          style: AppFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontSize: 14,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}

