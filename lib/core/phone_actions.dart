import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showPhoneActionSheet(BuildContext context, String rawNumber) async {
  final number = rawNumber.trim();
  if (number.isEmpty) return;

  String normalized(String n) {
    var digits = n.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('+')) digits = digits.substring(1);
    return digits;
  }

  final telUri = Uri.parse('tel:$number');
  final waUri = Uri.parse('https://wa.me/${normalized(number)}');

  await showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.phone, color: Color(0xFFFF6B35)),
            title: const Text('Call'),
            onTap: () async {
              Navigator.pop(ctx);
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
            title: const Text('WhatsApp'),
            onTap: () async {
              Navigator.pop(ctx);
              if (await canLaunchUrl(waUri)) {
                await launchUrl(waUri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Color(0xFF4A90E2)),
            title: const Text('Copy Number'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: number));
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Number copied to clipboard')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
