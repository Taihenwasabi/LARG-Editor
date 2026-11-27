import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:larg_editor/i18n/i18n.dart';
import 'package:larg_editor/page/editor/index.dart';
import 'package:larg_editor/service/video_plugin_init.dart';
import 'package:larg_editor/store/app_settings.dart';
import 'package:larg_editor/theme/app_theme.dart';

const String kAppLang = 'zh-CN';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initVideoPlugin();
  await I18n.instance.init(kAppLang);
  await AppSettings.instance.load();
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
      themeMode: ThemeMode.dark,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const EditorPage(),
    );
  }
}
