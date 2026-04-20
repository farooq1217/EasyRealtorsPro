import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/drift.dart' hide Column;
import 'package:drift/web.dart';

/// Web-only app implementation that excludes sqlite3 FFI dependencies
class WebOnlyApp extends StatelessWidget {
  const WebOnlyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('This is a web-only build'),
        ),
      );
    }

    return MaterialApp(
      title: 'EasyRealtorsPro - Web',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WebHomePage(),
    );
  }
}

class WebHomePage extends StatelessWidget {
  const WebHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyRealtorsPro - Web Version'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Web Build Successful!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'FFI dependencies excluded for web compatibility',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
