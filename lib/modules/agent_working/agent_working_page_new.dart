import 'package:flutter/material.dart';
import 'package:shared/shared.dart' show AppDatabase;
import '../../presentation/agent_working/agent_working_page_clean.dart' as clean_arch;

// This is entry point that maintains the original import path
// but delegates to clean architecture implementation
class AgentWorkingPage extends StatelessWidget {
  final AppDatabase db;
  
  const AgentWorkingPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return clean_arch.AgentWorkingPageClean(db: db);
  }
}
