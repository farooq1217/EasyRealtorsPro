// lib/features/follow_up/pages/follow_up_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:shared/src/db/schema.dart' show AppDatabase;
import '../../../core/services/app_storage.dart';
import '../../../core/services/auth/auth_service.dart';
import '../../../core/role_utils.dart';
import '../../../core/font_utils.dart';
import '../view_models/follow_up_view_model.dart';
import '../models/follow_up.dart';

/// Follow Up page with premium SaaS aesthetic.
class FollowUpPage extends StatefulWidget {
  final AppDatabase db;

  const FollowUpPage({Key? key, required this.db}) : super(key: key);

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  late FollowUpViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Retrieve the provider after the widget tree is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel = Provider.of<FollowUpViewModel>(context, listen: false);
      _viewModel.loadFollowUps();
    });
  }

  Future<void> _showAddEditDialog({FollowUp? existing}) async {
    final isEditing = existing != null;
    final titleController = TextEditingController(text: existing?.clientName ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    DateTime selectedDate = existing?.followUpDate ?? DateTime.now();
    TimeOfDay selectedTime = existing?.followUpTime != null
        ? TimeOfDay(
            hour: int.parse(existing!.followUpTime.split(':')[0].replaceAll(RegExp(r'[^0-9]'), '')),
            minute: int.parse(existing.followUpTime.split(':')[1].replaceAll(RegExp(r'[^0-9]'), '')),
          )
        : const TimeOfDay(hour: 9, minute: 0);
    String status = existing?.status ?? 'pending';

    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Follow‑Up' : 'New Follow‑Up',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Client Name',
                          labelStyle: TextStyle(color: Colors.black54),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black38)),
                        ),
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          labelStyle: TextStyle(color: Colors.black54),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black38)),
                        ),
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) setDialogState(() => selectedDate = date);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black38))),
                                child: Text(
                                  'Date: ${selectedDate.toLocal().toIso8601String().split('T')[0]}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (time != null) setDialogState(() => selectedTime = time);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black38))),
                                child: Text(
                                  'Time: ${selectedTime.format(context)}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                        ],
                        onChanged: (v) => setDialogState(() => status = v ?? status),
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(color: Colors.black54),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black38)),
                        ),
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (titleController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields')));
                              return;
                            }
                            final followUp = FollowUp(
                              id: existing?.id ?? UniqueKey().toString(),
                              clientName: titleController.text,
                              followUpDate: selectedDate,
                              followUpTime: selectedTime.format(context),
                              note: noteController.text.isEmpty ? null : noteController.text,
                              status: status,
                              companyId: RoleUtils.getUserCompanyId(AuthService.currentUser) ?? '',
                              createdBy: AuthService.currentUser?['id']?.toString() ?? '',
                            );
                            final success = isEditing ? await _viewModel.updateFollowUp(followUp) : await _viewModel.addFollowUp(followUp);
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(isEditing ? 'Update' : 'Create'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(200),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF2C3E50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                children: const [
                  Icon(Icons.event_available, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Text('Follow‑Up', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Consumer<FollowUpViewModel>(
        builder: (context, vm, _) {
          if (vm.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.error != null) {
            return Center(child: Text(vm.error!, style: const TextStyle(color: Colors.red)));
          }
          if (vm.followUps.isEmpty) {
            return const Center(child: Text('No follow‑up items yet.', style: TextStyle(fontSize: 16)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.followUps.length,
            itemBuilder: (context, index) {
              final item = vm.followUps[index];
              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete Follow‑Up'),
                      content: const Text('Are you sure you want to delete this item?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  await vm.deleteFollowUp(item.id);
                },
                child: GestureDetector(
                  onTap: () => _showAddEditDialog(existing: item),
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.clientName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text('Date: ${item.followUpDate.toLocal().toIso8601String().split('T')[0]}', style: const TextStyle(color: Colors.black54)),
                            Text('Time: ${item.followUpTime}', style: const TextStyle(color: Colors.black54)),
                            if (item.note != null) ...[
                              const SizedBox(height: 6),
                              Text(item.note!, style: const TextStyle(color: Colors.black54)),
                            ],
                            const SizedBox(height: 6),
                            Chip(
                              label: Text(item.status, style: const TextStyle(color: Colors.white)),
                              backgroundColor: item.status == 'completed' ? Colors.green : (item.status == 'overdue' ? Colors.redAccent : Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4A90E2),
        icon: const Icon(Icons.add),
        label: const Text('Add Follow‑Up'),
        onPressed: () => _showAddEditDialog(),
      ),
    );
  }
}
