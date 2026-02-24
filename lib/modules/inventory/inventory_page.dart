// modules/inventory/inventory_page.dart - Clean Architecture Entry Point
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/inventory/inventory_page.dart' as clean_arch;
import '../../domain/models/inventory_item.dart';
import '../../data/repositories/inventory_repository_impl.dart';

// This is entry point that maintains the original import path
// but delegates to clean architecture implementation
class FilesPage extends StatelessWidget {
  final dynamic db;
  
  const FilesPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return clean_arch.InventoryPage(db: db);
  }
}
