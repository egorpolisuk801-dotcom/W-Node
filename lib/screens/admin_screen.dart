import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_link.dart';
import '../core/app_colors.dart';
import '../core/camo_button.dart';

/// Адмінка на телефоні: ті самі пристрої і термінал, що на Mac і Windows.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _input = TextEditingController();
  final _host = TextEditingController();
  final _noticeInput = TextEditingController();
  final _link = AdminLink.instance;
  bool _downloading = false;
  double _progress = 0;

  Color get _bg => AppColors.bg;
  Color get _card => AppColors.card;
  Color get _border => AppColors.border;
  Color get _copper => AppColors.accent;
  Color get _text => AppColors.textMain;
  Color get _muted => AppColors.muted;
  Color get _live => AppColors.accent;
  int _seenLines = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _link.addListener(_onLink);
    _link.start();
  }

  void _onLink() {
    final lines = (_link.state['lines'] as List?) ?? [];
    if (_armed && lines.length > _seenLines) {
      final last = lines.isEmpty ? null : lines.last;
      final name = last is Map ? '${last['name'] ?? ''}' : '';
      if (name.isNotEmpty && name != _link.deviceName) {
        HapticFeedback.mediumImpact();
      }
    }
    _seenLines = lines.length;
    _armed = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _link.removeListener(_onLink);
    _input.dispose();
    _host.dispose();
    _noticeInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _link.state;
    final devices = (state['devices'] as List?) ?? [];
    final changes = (state['changes'] as List?) ?? [];
    final lines = (state['lines'] as List?) ?? [];
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded, color: _text),
                ),
                _mark(),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('КОМАНДНИЙ ЦЕНТР',
                          style: TextStyle(
                              color: _copper,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      Text('Адмін',
                          style: TextStyle(
                              color: _text,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.0)),
                      Text('v${_link.versionLabel}',
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                ),
                _pill(_link.status, _link.live),
              ],
            ),
            SizedBox(height: 14),
            if (!_link.tailscaleInstalled) _tailscaleAlert(),
            if (!_link.tailscaleInstalled) SizedBox(height: 12),
            _banner(state),
            SizedBox(height: 12),
            _notice(state),
            SizedBox(height: 12),
            _cardBox(
              'ПРИСТРОЇ',
              devices.isEmpty
                  ? [
                      Text('Поки немає інших пристроїв. Кожен комп’ютер і телефон з цією адмінкою з’явиться тут.',
                          style: TextStyle(color: _muted, height: 1.35))
                    ]
                  : [
                      for (final raw in devices)
                        if (raw is Map) _device(raw),
                    ],
            ),
            SizedBox(height: 12),
            _cardBox(
              'ХТО ЗАХОДИВ',
              _visits(state),
            ),
            SizedBox(height: 12),
            _cardBox(
              'ЗМІНИ',
              changes.isEmpty
                  ? [
                      Text('Список з’явиться, коли буде зв’язок.',
                          style: TextStyle(color: _muted))
                    ]
                  : [
                      for (final raw in changes)
                        if (raw is Map) _change(raw),
                    ],
            ),
            SizedBox(height: 12),
            _cardBox('ТЕРМІНАЛ', [
              Container(
                height: 200,
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF0B1018),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Color(0xFF3A4632)),
                ),
                child: lines.isEmpty
                    ? Text('Спільний термінал з Mac і Windows.',
                        style: TextStyle(color: _muted))
                    : ListView(
                        children: [
                          for (final raw in lines.length > 40
                              ? lines.sublist(lines.length - 40)
                              : lines)
                            if (raw is Map) _termLine(raw),
                        ],
                      ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: TextStyle(color: _text),
                      cursorColor: _copper,
                      decoration: _field('Написати в спільний термінал…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  SizedBox(width: 8),
                  _copperButton('Надіслати', _send),
                ],
              ),
            ]),
            SizedBox(height: 12),
            _cardBox('АДРЕСА WINDOWS', [
              Text(
                'Якщо телефон в іншій мережі, впиши адресу з адмінки Windows.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _host,
                      style: TextStyle(color: _text),
                      cursorColor: _copper,
                      decoration: _field('100.64.253.111'),
                      onSubmitted: _link.useHost,
                    ),
                  ),
                  SizedBox(width: 8),
                  _copperButton('Знайти', () => _link.useHost(_host.text)),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tailscaleAlert() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Color(0xFF102028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _copper),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ПОТРІБЕН TAILSCALE',
              style: TextStyle(color: _copper, fontSize: 11, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Встановіть Tailscale на цей телефон',
              style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(
            'Без нього пристрої в іншій мережі один одного не бачать.',
            style: TextStyle(color: _muted, height: 1.35),
          ),
          SizedBox(height: 10),
          _copperButton('Встановити Tailscale', () {
            launchUrl(
              Uri.parse('https://play.google.com/store/apps/details?id=com.tailscale.ipn'),
              mode: LaunchMode.externalApplication,
            );
          }),
        ],
      ),
    );
  }

  Widget _banner(Map<String, dynamic> state) {
    final scope = (state['release_scope'] ?? '').toString();
    final apkReady = state['phone_apk_ready'] == true;
    final same = _link.samePhoneVersion();
    final offer = _link.phoneUpdateReady && Platform.isAndroid;
    String title;
    String sub;
    if (! _link.live && state.isEmpty) {
      title = 'Шукаю адмінку';
      sub = 'Windows має бути відкритий. Кабель не потрібен.';
    } else if (!Platform.isAndroid) {
      title = 'iPhone оновлюється з Windows';
      sub = 'Підключи iPhone кабелем до комп’ютера. З самого телефону пакет не ставиться.';
    } else if (scope == 'pc') {
      title = 'Оновлення тільки для комп’ютерів';
      sub = 'Телефон лишається як є.';
    } else if (scope == 'phone' && same) {
      title = 'Оновлення тільки для телефону';
      sub = 'На телефоні вже v${_link.versionLabel}. Комп’ютери не чіпає.';
    } else if (!apkReady && (scope == 'phone' || scope == 'all')) {
      title = 'Пакет для телефону ще не зібраний';
      sub = 'На Windows натисни «Зібрати для телефону».';
    } else if (same) {
      title = 'Програма актуальна';
      sub = 'На телефоні вже v${_link.versionLabel}.';
    } else if (offer) {
      title = scope == 'phone'
          ? 'Оновлення тільки для телефону'
          : 'Є оновлення v${state['phone_version']}';
      sub = _link.cloudPhoneReady
          ? 'Файл у хмарі. Windows може бути вимкнений.'
          : 'Зараз v${_link.versionLabel}. Ставиться само, без кабелю.';
    } else {
      title = 'Зв’язок є';
      sub = 'Усі комп’ютери і телефони в одній адмінці.';
    }
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Color(0xFF121A24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: offer ? _copper : Color(0xFF3A4632)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ОНОВЛЕННЯ',
              style: TextStyle(
                  color: _copper, fontSize: 11, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                  color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(sub, style: TextStyle(color: _muted, height: 1.35)),
          if (_downloading) ...[
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              color: _copper,
              backgroundColor: Color(0xFF2A3824),
            ),
          ],
          if (Platform.isAndroid) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _copperButton(
                _downloading ? 'Завантажую…' : 'Оновити програму',
                offer && !_downloading ? _update : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _update() async {
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    final path = await _link.downloadApk((value) {
      if (mounted) setState(() => _progress = value.clamp(0, 1));
    });
    if (!mounted) return;
    setState(() => _downloading = false);
    if (path == null) {
      _toast('Не вдалося завантажити оновлення');
      return;
    }
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final ok = await _link.say(text);
    if (!mounted) return;
    if (ok) {
      _input.clear();
    } else {
      _toast('Немає зв’язку з Windows');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: _card,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _mark() {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _copper,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text('W',
          style: TextStyle(
              color: Color(0xFF1A140C),
              fontSize: 26,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _pill(String text, bool live) {
    return Container(
      constraints: BoxConstraints(maxWidth: 132),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: live ? _live : Color(0xFF243024),
        borderRadius: BorderRadius.circular(999),
        border: live ? null : Border.all(color: Color(0xFF3A4632)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: live ? Color(0xFF1A140C) : _text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cardBox(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF3A4632)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _copper,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  color: Color(0xFFC6D36A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _notice(Map<String, dynamic> state) {
    final notice = state['notice'];
    final data = notice is Map ? Map<String, dynamic>.from(notice) : <String, dynamic>{};
    final text = '${data['text'] ?? ''}'.trim();
    final reads = data['reads'] is Map ? Map<String, dynamic>.from(data['reads'] as Map) : <String, dynamic>{};
    final names = [
      for (final item in reads.values)
        if (item is Map) '${item['name'] ?? ''}' else '',
    ].where((item) => item.isNotEmpty).join(', ');
    return _cardBox('ОГОЛОШЕННЯ', [
      Text(
        text.isEmpty ? 'Поки немає оголошення' : text,
        style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800),
      ),
      SizedBox(height: 4),
      Text(
        text.isEmpty
            ? 'Окремо від термінала. Кнопка «Прочитав» на кожному пристрої.'
            : '${data['name'] ?? '—'} · ${data['t'] ?? ''} · ${names.isEmpty ? 'Ще ніхто не прочитав' : 'Прочитали: $names'}',
        style: TextStyle(color: _muted, height: 1.35),
      ),
      SizedBox(height: 8),
      TextField(
        controller: _noticeInput,
        style: TextStyle(color: _text),
        cursorColor: _copper,
        decoration: _field('Коротке оголошення для всіх…'),
        onSubmitted: (_) => _sendNotice(),
      ),
      SizedBox(height: 8),
      Row(
        children: [
          _copperButton('Оголосити', _sendNotice),
          SizedBox(width: 8),
          _copperButton(reads.containsKey(_link.deviceId) ? 'Прочитано' : 'Прочитав',
              text.isEmpty || reads.containsKey(_link.deviceId) ? null : _link.markNoticeRead),
        ],
      ),
    ]);
  }

  Future<void> _sendNotice() async {
    final text = _noticeInput.text.trim();
    if (text.isEmpty) return;
    final ok = await _link.postNotice(text);
    if (!mounted) return;
    if (ok) {
      _noticeInput.clear();
    } else {
      _toast('Оголошення не відправилось');
    }
  }

  List<Widget> _visits(Map<String, dynamic> state) {
    final raw = state['visits'];
    final items = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    if (items.isEmpty) {
      return [
        Text('За тиждень нових заходжень ще немає.', style: TextStyle(color: _muted, height: 1.35)),
      ];
    }
    return [
      for (final item in items.take(12))
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            '${item['t'] ?? ''}  ${item['name'] ?? ''} · ${item['system'] ?? ''} · v${item['version'] ?? '—'}',
            style: TextStyle(color: _text, height: 1.3),
          ),
        ),
    ];
  }

  Widget _device(Map raw) {
    final online = raw['online'] == true;
    final system = '${raw['system'] ?? ''}';
    final letter = system == 'Mac'
        ? 'M'
        : system == 'Windows'
            ? 'W'
            : 'T';
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1C2533),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: online ? Color(0xFF3A4632) : _border),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 64,
            decoration: BoxDecoration(
              color: online ? _live : Color(0xFF3A4632),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _copper,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(letter,
                style: TextStyle(
                    color: Color(0xFF1A140C),
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${raw['name'] ?? '—'}',
                    style: TextStyle(
                        color: _text, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text(
                  '$system · ${raw['ip'] ?? ''} · v${raw['version'] ?? '—'}',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                _freshLine(raw),
              ],
            ),
          ),
          SizedBox(width: 8),
          _pill(online ? 'в мережі' : 'немає', online),
        ],
      ),
    );
  }

  Widget _freshLine(Map raw) {
    final text = _fresh(raw);
    if (text.isEmpty) return SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        color: text.contains('відстає') ? Color(0xFFFF8F8F) : _live,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _fresh(Map raw) {
    final system = '${raw['system'] ?? ''}'.toLowerCase();
    final version = '${raw['version'] ?? ''}';
    final admin = '${raw['admin'] ?? ''}';
    final state = _link.state;
    final phone = system.contains('тел') || system.contains('phone') || system.contains('iphone');
    if (phone) {
      final latest = '${state['phone_version'] ?? ''}';
      final build = '${state['phone_build'] ?? ''}';
      if (latest.isEmpty || version.isEmpty || version == '—') return '';
      final target = build.isEmpty ? latest : '$latest+$build';
      return version == target || version == latest ? 'програма актуальна' : 'програма відстає';
    }
    final latest = '${state['version'] ?? ''}';
    final remoteAdmin = '${state['admin_version'] ?? ''}';
    final parts = <String>[];
    if (latest.isNotEmpty && version.isNotEmpty && version != '—') {
      parts.add(version == latest ? 'програма актуальна' : 'програма відстає');
    }
    if (remoteAdmin.isNotEmpty && admin.isNotEmpty) {
      parts.add(admin == remoteAdmin ? 'адмінка актуальна' : 'адмінка відстає');
    }
    return parts.join('  ·  ');
  }

  Widget _change(Map raw) {
    final scope = '${raw['scope'] ?? 'pc'}';
    final tag = scope == 'all'
        ? 'всюди'
        : scope == 'phone'
            ? 'телефон'
            : 'ПК';
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: 'v${raw['version'] ?? ''}  ',
            style: TextStyle(color: _copper, fontWeight: FontWeight.w800)),
        TextSpan(
            text: '$tag  ',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        TextSpan(
            text: '${raw['text'] ?? ''}',
            style: TextStyle(color: _text, height: 1.3)),
      ])),
    );
  }

  Widget _termLine(Map raw) {
    final name = '${raw['name'] ?? ''}';
    final low = name.toLowerCase();
    Color color = _copper;
    if (low.contains('mac')) color = Color(0xFF8FB7D6);
    if (low.contains('тел') || low.contains('phone') || low.contains('iphone')) {
      color = _live;
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '${raw['t'] ?? ''}  ',
            style: TextStyle(color: Color(0xFF8E9884), fontSize: 12)),
        TextSpan(
            text: '$name  ',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        TextSpan(
            text: '${raw['text'] ?? ''}',
            style: TextStyle(color: _text, fontSize: 12)),
      ])),
    );
  }

  InputDecoration _field(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Color(0xFF8E9884)),
      filled: true,
      fillColor: Color(0xFF121810),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _copper),
      ),
    );
  }

  Widget _copperButton(String label, VoidCallback? onTap) {
    return CamoButton(
      label: label,
      onPressed: onTap,
      tone: CamoToneData.cycle(label.hashCode),
      compact: true,
    );
  }
}
