// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modules/constants.dart';
import 'modules/logger_config.dart';
import 'modules/logic.dart';
import 'modules/ui/styles.dart';
import 'modules/ui/main_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  await initLogger();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AdbMonitor()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: '$appName v$appVersion',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainWindow(),
    );
  }
}
