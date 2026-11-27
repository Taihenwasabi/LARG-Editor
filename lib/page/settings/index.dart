/// 设置页：AI 裁判配置、语言（当前仅中文）、关于。
///
/// 无后端：AI 配置只存本机，密钥不离开这台电脑。
library;

import 'package:flutter/material.dart';
import 'package:larg_editor/api/ai_chat.dart';
import 'package:larg_editor/store/app_settings.dart';
import 'package:larg_editor/theme/canvas_skin.dart';
import 'package:larg_editor/theme/tokens.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _connectCtrl = TextEditingController();
  final _receiveCtrl = TextEditingController();

  bool _testing = false;
  String? _testResult;
  bool _testOk = false;
  bool _saved = false;

  AiConfig get _ai => AppSettings.instance.ai;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  void _loadFields() {
    _baseUrlCtrl.text = _ai.baseUrl;
    _modelCtrl.text = _ai.model;
    _keyCtrl.text = _ai.apiKey;
    _connectCtrl.text = '${_ai.connectTimeoutSeconds}';
    _receiveCtrl.text = '${_ai.receiveTimeoutSeconds}';
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _keyCtrl.dispose();
    _connectCtrl.dispose();
    _receiveCtrl.dispose();
    super.dispose();
  }

  void _applyFields() {
    _ai
      ..baseUrl = _baseUrlCtrl.text.trim()
      ..model = _modelCtrl.text.trim()
      ..apiKey = _keyCtrl.text.trim()
      ..connectTimeoutSeconds = int.tryParse(_connectCtrl.text.trim()) ?? 20
      ..receiveTimeoutSeconds = int.tryParse(_receiveCtrl.text.trim()) ?? 60;
  }

  Future<void> _test() async {
    _applyFields();
    if (!_ai.ready) {
      setState(() {
        _testOk = false;
        _testResult = '先把「接口地址」「模型」「密钥」都填上再测试';
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final ms = await AiChatApi.instance.testConnection();
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testResult = '连接成功，用时 $ms 毫秒';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testResult = '连接失败：$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    _applyFields();
    await AppSettings.instance.saveAi();
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已保存')));
  }

  void _pickProvider(String id) {
    setState(() {
      AppSettings.instance.applyProvider(id);
      _loadFields();
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          _section('AI 裁判'),
          const Text(
            '用于判定「答题 / 开放文本」类校验。不填则所有题目只用本地判定，不联网。',
            style: TextStyle(fontSize: 12, color: CanvasSkin.lightMuted),
          ),
          const SizedBox(height: 16),
          _label('服务商'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in kAiProviders)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _ai.providerId == p.id,
                  onSelected: (_) => _pickProvider(p.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _field(_baseUrlCtrl, '接口地址', 'https://api.deepseek.com'),
          _field(_modelCtrl, '模型', 'deepseek-chat'),
          _field(_keyCtrl, '密钥', 'sk-…', obscure: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(_connectCtrl, '连接超时（秒）', '20')),
              const SizedBox(width: 12),
              Expanded(child: _field(_receiveCtrl, '等待回复（秒）', '60')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _testing ? null : _test,
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('测试连接'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _save,
                child: Text(_saved ? '再保存一次' : '保存'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _testOk
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: FiftyRadii.mdRadius,
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testOk ? Colors.green.shade300 : Colors.red.shade300,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          _section('语言'),
          const Text(
            '当前版本只提供简体中文；其它语言将在后续版本补充。',
            style: TextStyle(fontSize: 12, color: CanvasSkin.lightMuted),
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.translate, size: 18),
            title: Text('简体中文'),
            trailing: Icon(Icons.check, size: 18),
          ),
          const SizedBox(height: 32),
          _section('关于'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('LARG Editor'),
            subtitle: Text('把剧本做成 LARG 游戏包 · 版本 1.0.0'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('许可'),
            subtitle: Text('MIT License'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('说明'),
            subtitle: Text('离线工具：不上传剧本、不需要登录。AI 裁判只连接你自己配置的接口。'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: CanvasSkin.lightMuted),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }
}
