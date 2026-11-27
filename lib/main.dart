import 'package:flutter/material.dart';
import 'package:larg_editor/page/editor/index.dart';
import 'package:larg_editor/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LargEditorApp());
}

class LargEditorApp extends StatelessWidget {
  const LargEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LARG Editor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const EditorPage(),
    );
  }
}
