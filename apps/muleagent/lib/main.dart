import 'package:flutter/material.dart';
import 'package:operador/design/mule_theme.dart';

import 'application/unified_bundle.dart';
import 'application/unified_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MuleAgentApp());
}

/// INTERFAZ_MULEAGENT_V1: one theme for both profiles and all screens.
class MuleAgentApp extends StatefulWidget {
  const MuleAgentApp({super.key, this.bundle});
  final UnifiedBundle? bundle;

  @override
  State<MuleAgentApp> createState() => _MuleAgentAppState();
}

class _MuleAgentAppState extends State<MuleAgentApp> {
  ThemeMode themeMode = ThemeMode.light;

  void changeTheme(ThemeMode mode) {
    if (mounted && themeMode != mode) {
      setState(() => themeMode = mode);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MuleAgent',
    debugShowCheckedModeBanner: false,
    theme: muleTheme(Brightness.light),
    darkTheme: muleTheme(Brightness.dark),
    themeMode: themeMode,
    home: UnifiedShell(
      bundle: widget.bundle,
      onThemeChanged: changeTheme,
    ),
  );
}
