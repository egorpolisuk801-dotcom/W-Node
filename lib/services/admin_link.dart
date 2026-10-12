import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Зв’язок телефону з адмінкою Windows: ті самі пристрої, термінал і оновлення.
class AdminLink extends ChangeNotifier {
  AdminLink._();
  static final AdminLink instance = AdminLink._();

  static const token = 'w12-lan';
  static const port = 8766;
  static const beaconPort = 38714;
  static const homeIp = '192.168.0.101';
  static const tailscaleIp = '100.64.253.111';
  static const tailscaleDns = 'razer.tail491d46.ts.net';
  static const cloud = 'https://qzgatfjezjzqshqpuejh.supabase.co';
  static const cloudKey = 'sb_publishable_KdPbnLB4DpKjjaoPP9agig_EWMpdM7h';

  Map<String, dynamic> cloudRelease = {};

  String base = '';
  String status = 'Шукаю Windows…';
  bool live = false;
  Map<String, dynamic> state = {};
  String versionLabel = '—';

  Timer? _timer;
  RawDatagramSocket? _udp;
  bool _busy = false;
  bool _started = false;
  String _name = 'Телефон';
  String deviceId = '';
  bool tailscaleInstalled = true;

  static const _deviceChannel = MethodChannel('w12/device');

  String get systemLabel => Platform.isIOS ? 'iPhone' : 'Телефон';
  String get deviceName => _name;

  Future<void> start() async {
    if (!_started) {
      _started = true;
      final host = Platform.localHostname.split('.').first.trim();
      if (host.isNotEmpty && host.toLowerCase() != 'localhost') {
        _name = host;
      } else {
        _name = systemLabel;
      }
      try {
        final info = await PackageInfo.fromPlatform();
        versionLabel = info.buildNumber.isEmpty
            ? info.version
            : '${info.version}+${info.buildNumber}';
      } catch (_) {}
      _listenBeacon();
      deviceId = await _loadDeviceId();
      await _checkTailscale();
    }
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) => tick());
    await pullCloud();
    await tick();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    live = false;
    status = 'Адмінка на паузі';
    notifyListeners();
  }

  final _hints = <String>{};

  bool _isLan(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.');
  }

  Future<List<String>> _candidates() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('w12_admin_base') ?? '';
    final lan = prefs.getString('w12_admin_lan') ?? '';
    final ts = prefs.getString('w12_admin_ts') ?? '';
    final dns = prefs.getString('w12_admin_dns') ?? '';
    final urls = <String>[
      if (base.isNotEmpty) base,
      if (saved.isNotEmpty) saved,
      'http://$homeIp:$port',
      if (lan.isNotEmpty) 'http://$lan:$port',
      if (ts.isNotEmpty) 'http://$ts:$port',
      'http://$tailscaleIp:$port',
      'http://$tailscaleDns:$port',
      if (dns.isNotEmpty) 'http://$dns:$port',
      ..._hints,
    ];
    final seen = <String>{};
    return [for (final url in urls) if (seen.add(url)) url];
  }

  Future<void> _remember() async {
    final prefs = await SharedPreferences.getInstance();
    if (base.isNotEmpty) await prefs.setString('w12_admin_base', base);
    final lan = (state['lan_ip'] ?? '').toString();
    final ts = (state['tailscale_ip'] ?? '').toString();
    if (lan.isNotEmpty && lan != '127.0.0.1') {
      await prefs.setString('w12_admin_lan', lan);
    }
    if (ts.startsWith('100.')) await prefs.setString('w12_admin_ts', ts);
    final dns = (state['tailscale_dns'] ?? '').toString().replaceAll(RegExp(r'\.$'), '');
    if (dns.contains('.')) await prefs.setString('w12_admin_dns', dns);
  }

  Future<String?> _race(List<String> urls) async {
    if (urls.isEmpty) return null;
    final pending = urls.length;
    var left = pending;
    String? lanHit;
    String? anyHit;
    final done = Completer<String?>();
    for (final url in urls) {
      final lan = _isLan(url);
      _get('$url/api/state?t=$token').then((data) {
        if (data != null) {
          anyHit ??= url;
          if (lan) lanHit = url;
        }
        left -= 1;
        if (!done.isCompleted && (lanHit != null || left == 0)) {
          done.complete(lanHit ?? anyHit);
        }
      });
    }
    return done.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => lanHit ?? anyHit,
    );
  }

  DateTime _roomAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<String> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('w12_device_id') ?? '';
    if (saved.isNotEmpty) return saved;
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    await prefs.setString('w12_device_id', id);
    return id;
  }

  Future<void> _checkTailscale() async {
    if (!Platform.isAndroid) {
      tailscaleInstalled = true;
      return;
    }
    try {
      tailscaleInstalled =
          await _deviceChannel.invokeMethod<bool>('tailscaleInstalled') == true;
    } catch (_) {
      tailscaleInstalled = false;
    }
  }

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await pullCloud();
      var linked = false;
      if (base.isNotEmpty && await _exchange(base)) {
        await _remember();
        linked = true;
      } else {
        final previous = base;
        base = '';
        if (previous.isNotEmpty) {
          status = 'Перемикаю мережу…';
          notifyListeners();
        }
        final winner = await _race(await _candidates());
        if (winner != null && await _exchange(winner)) {
          await _remember();
          linked = true;
        }
      }
      await _syncCloud(linked);
    } finally {
      _busy = false;
    }
  }

  Future<void> useHost(String raw) async {
    var host = raw.trim().replaceFirst(RegExp(r'^https?://'), '');
    host = host.split('/').first;
    if (host.isEmpty) return;
    final url = host.contains(':') ? 'http://$host' : 'http://$host:$port';
    if (await _exchange(url)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('w12_admin_base', url);
    } else {
      status = 'За цією адресою адмінки немає';
      notifyListeners();
    }
  }

  Future<bool> say(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (base.isNotEmpty) {
      final ok = await _post('$base/api/say?t=$token', {
        'name': _name,
        'text': trimmed,
      });
      if (ok != null) return true;
    }
    final wrote = await _cloudSay(trimmed);
    if (wrote) {
      _roomAt = DateTime.fromMillisecondsSinceEpoch(0);
      await _syncCloud(false);
    }
    return wrote;
  }

  Future<bool> postNotice(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (base.isNotEmpty) {
      final ok = await _post('$base/api/notice?t=$token', {
        'name': _name,
        'text': trimmed,
        'id': deviceId,
      });
      if (ok != null) {
        await tick();
        return true;
      }
    }
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch ~/ 1000;
    String two(int n) => n.toString().padLeft(2, '0');
    final wrote = await _cloudWrite('w12_notice', jsonEncode({
      'id': '$stamp',
      'name': _name,
      'text': trimmed,
      't': '${two(now.day)}.${two(now.month)} ${two(now.hour)}:${two(now.minute)}',
      'ts': stamp,
      'reads': {},
    }));
    if (wrote) {
      _roomAt = DateTime.fromMillisecondsSinceEpoch(0);
      await _syncCloud(false);
    }
    return wrote;
  }

  Future<bool> markNoticeRead() async {
    if (base.isNotEmpty) {
      final ok = await _post('$base/api/notice/read?t=$token', {
        'name': _name,
        'id': deviceId,
      });
      if (ok != null) {
        await tick();
        return true;
      }
    }
    final raw = await _cloudValue('w12_notice', limit: const Duration(seconds: 8));
    if (raw.isEmpty) return false;
    try {
      final notice = jsonDecode(raw);
      if (notice is! Map || '${notice['id'] ?? ''}'.isEmpty) return false;
      final reads = Map<String, dynamic>.from(
        notice['reads'] is Map ? notice['reads'] as Map : const {},
      );
      reads[deviceId] = {
        'name': _name,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      notice['reads'] = reads;
      final wrote = await _cloudWrite('w12_notice', jsonEncode(notice));
      if (wrote) {
        _roomAt = DateTime.fromMillisecondsSinceEpoch(0);
        await _syncCloud(false);
      }
      return wrote;
    } catch (_) {
      return false;
    }
  }

  bool samePhoneVersion() {
    return _sameAs(
      (state['phone_version'] ?? '').toString(),
      (state['phone_build'] ?? '').toString(),
    );
  }

  Future<void> pullCloud() async {
    final raw = await _cloudValue('w12_release');
    if (raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        cloudRelease = data;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _syncCloud(bool linked) async {
    final now = DateTime.now();
    await _checkTailscale();
    if (linked && now.difference(_roomAt).inSeconds < 10) return;
    _roomAt = now;
    final seen = now.millisecondsSinceEpoch ~/ 1000;
    if (deviceId.isEmpty) deviceId = await _loadDeviceId();
    final mine = {
      'id': deviceId,
      'name': _name,
      'system': systemLabel,
      'version': versionLabel,
      'ip': '',
      'seen': seen,
    };
    final roomRaw = await _cloudValue('w12_room', limit: const Duration(seconds: 8));
    final roomDevices = <String, Map<String, dynamic>>{};
    if (roomRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(roomRaw);
        final list = parsed is Map ? parsed['devices'] : null;
        if (list is Map) {
          list.forEach((key, value) {
            if (value is Map) roomDevices['$key'] = Map<String, dynamic>.from(value);
          });
        }
      } catch (_) {}
    }
    roomDevices[deviceId] = mine;
    roomDevices.removeWhere((key, value) {
      final stamp = int.tryParse('${value['seen'] ?? 0}') ?? 0;
      return stamp <= 0 || seen - stamp > 14 * 24 * 3600;
    });
    await _cloudWrite('w12_room', jsonEncode({'devices': roomDevices}));
    await _cloudWrite('w12_peer_phone', jsonEncode(mine));
    final chatRaw = await _cloudValue('w12_chat', limit: const Duration(seconds: 8));
    final raw = [roomRaw, chatRaw];
    final devices = <Map<String, dynamic>>[];
    if (linked) {
      for (final item in (state['devices'] as List? ?? const [])) {
        if (item is Map && item['ip'] != 'хмара') {
          devices.add(Map<String, dynamic>.from(item));
        }
      }
    }
    final names = {for (final item in devices) '${item['name']}'};
    var others = false;
    for (final peer in roomDevices.values) {
      final name = '${peer['name'] ?? ''}';
      final id = '${peer['id'] ?? ''}';
      if (name.isEmpty || id == deviceId || name == _name || names.contains(name)) continue;
      final stamp = int.tryParse('${peer['seen'] ?? 0}') ?? 0;
      final online = stamp > 0 && seen - stamp < 45;
      if (online) others = true;
      devices.add({
        'id': id,
        'name': name,
        'system': '${peer['system'] ?? ''}',
        'ip': '${peer['ip'] ?? ''}'.isEmpty ? 'хмара' : '${peer['ip']}',
        'version': '${peer['version'] ?? '—'}',
        'online': online,
      });
    }
    var lines = <Map<String, dynamic>>[
      for (final item in (state['lines'] as List? ?? const []))
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    if (!linked && raw.length > 1 && raw[1].isNotEmpty) {
      try {
        final chat = jsonDecode(raw[1]);
        final list = chat is Map ? chat['lines'] : null;
        if (list is List) {
          lines = [
            for (final item in list)
              if (item is Map) Map<String, dynamic>.from(item),
          ];
        }
      } catch (_) {}
    }
    var visits = state['visits'];
    var notice = state['notice'];
    if (!linked) {
      final visitsRaw = await _cloudValue('w12_visits', limit: const Duration(seconds: 8));
      final noticeRaw = await _cloudValue('w12_notice', limit: const Duration(seconds: 8));
      if (visitsRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(visitsRaw);
          final items = parsed is Map ? parsed['items'] : null;
          if (items is List) {
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            visits = [
              for (final item in items)
                if (item is Map && now - (int.tryParse('${item['ts'] ?? 0}') ?? 0) < 7 * 24 * 3600)
                  Map<String, dynamic>.from(item),
            ];
          }
        } catch (_) {}
      }
      if (noticeRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(noticeRaw);
          if (parsed is Map) notice = Map<String, dynamic>.from(parsed);
        } catch (_) {}
      }
    }
    state = {
      ...state,
      'devices': devices,
      'lines': lines,
      if (visits != null) 'visits': visits,
      if (notice != null) 'notice': notice,
      if (!linked) 'release_scope': cloudRelease['scope'] ?? state['release_scope'] ?? 'pc',
      if (!linked) 'phone_version': cloudRelease['phone_version'] ?? '',
      if (!linked) 'phone_build': '${cloudRelease['phone_build'] ?? ''}',
    };
    if (!linked) {
      live = others;
      status = others ? 'Хмара · є зв’язок' : 'Хмара · Windows вимкнений';
    }
    notifyListeners();
  }

  Future<bool> _cloudSay(String text) async {
    final raw = await _cloudValue('w12_chat', limit: const Duration(seconds: 8));
    final lines = <Map<String, dynamic>>[];
    if (raw.isNotEmpty) {
      try {
        final chat = jsonDecode(raw);
        final list = chat is Map ? chat['lines'] : null;
        if (list is List) {
          for (final item in list) {
            if (item is Map) lines.add(Map<String, dynamic>.from(item));
          }
        }
      } catch (_) {}
    }
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    lines.add({
      't': '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
      'name': _name,
      'text': text,
    });
    final kept = lines.length > 40 ? lines.sublist(lines.length - 40) : lines;
    return _cloudWrite('w12_chat', jsonEncode({'lines': kept}));
  }

  Future<bool> _cloudWrite(String key, String value) async {
    final client = HttpClient();
    try {
      final headers = {
        'apikey': cloudKey,
        'Authorization': 'Bearer $cloudKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      };
      final query = Uri.parse(
          '$cloud/rest/v1/global_settings?setting_key=eq.$key&select=setting_key');
      final look = await client.getUrl(query).timeout(const Duration(seconds: 8));
      headers.forEach(look.headers.set);
      final found = await look.close().timeout(const Duration(seconds: 8));
      final body = await found.transform(utf8.decoder).join();
      final rows = jsonDecode(body.isEmpty ? '[]' : body);
      final exists = found.statusCode == 200 && rows is List && rows.isNotEmpty;
      final uri = exists
          ? Uri.parse('$cloud/rest/v1/global_settings?setting_key=eq.$key')
          : Uri.parse('$cloud/rest/v1/global_settings');
      final request = exists
          ? await client.patchUrl(uri).timeout(const Duration(seconds: 8))
          : await client.postUrl(uri).timeout(const Duration(seconds: 8));
      headers.forEach(request.headers.set);
      final payload = exists
          ? utf8.encode(jsonEncode({'setting_value': value}))
          : utf8.encode(jsonEncode({'setting_key': key, 'setting_value': value}));
      request.contentLength = payload.length;
      request.add(payload);
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain();
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _cloudValue(String key, {Duration limit = const Duration(seconds: 40)}) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
          '$cloud/rest/v1/global_settings?setting_key=eq.$key&select=setting_value');
      final request = await client.getUrl(uri).timeout(limit);
      request.headers.set('apikey', cloudKey);
      request.headers.set('Authorization', 'Bearer $cloudKey');
      final response = await request.close().timeout(limit);
      if (response.statusCode != 200) return '';
      final body = await response.transform(utf8.decoder).join();
      final rows = jsonDecode(body);
      if (rows is List && rows.isNotEmpty) {
        return '${rows.first['setting_value'] ?? ''}';
      }
      return '';
    } catch (_) {
      return '';
    } finally {
      client.close(force: true);
    }
  }

  bool _sameAs(String remote, String build) {
    if (remote.isEmpty || remote == '—') return true;
    final localVer = versionLabel.split('+').first;
    final localBuild =
        versionLabel.contains('+') ? versionLabel.split('+').last : '';
    if (remote != localVer) return false;
    if (build.isEmpty || localBuild.isEmpty) return true;
    return build == localBuild;
  }

  bool get cloudPhoneReady {
    final scope = cloudRelease['scope'];
    if (scope != 'all' && scope != 'phone') return false;
    if (cloudRelease['has_phone'] != true) return false;
    final chunks = cloudRelease['phone_chunks'];
    if (chunks is! int || chunks <= 0) return false;
    return !_sameAs(
      '${cloudRelease['phone_version'] ?? ''}',
      '${cloudRelease['phone_build'] ?? ''}',
    );
  }

  bool get phoneUpdateReady {
    if (cloudPhoneReady) return true;
    final scope = state['release_scope'];
    if (scope != 'all' && scope != 'phone') return false;
    if (state['phone_apk_ready'] != true) return false;
    if ((state['phone_url'] ?? '').toString().isEmpty) return false;
    return !samePhoneVersion();
  }

  Future<String?> downloadApk(void Function(double progress) onProgress) async {
    if (cloudPhoneReady) return _downloadCloudApk(onProgress);
    final url = (state['phone_url'] ?? '').toString();
    if (url.isEmpty) return null;
    final client = HttpClient();
    IOSink? sink;
    try {
      client.connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) return null;
      final total = response.contentLength;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/WNode-update.apk');
      sink = file.openWrite();
      var got = 0;
      await for (final chunk in response) {
        got += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress(got / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return file.path;
    } catch (_) {
      return null;
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  Future<String?> _downloadCloudApk(void Function(double progress) onProgress) async {
    final chunks = cloudRelease['phone_chunks'];
    if (chunks is! int || chunks <= 0) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/WNode-update.apk');
    final sink = file.openWrite();
    try {
      for (var index = 0; index < chunks; index++) {
        final key = 'w12_phone_${index.toString().padLeft(3, '0')}';
        final encoded = await _cloudValue(key);
        if (encoded.isEmpty) return null;
        sink.add(base64Decode(encoded));
        onProgress((index + 1) / chunks);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } catch (_) {
      await sink.close();
      return null;
    }
  }

  Future<bool> _exchange(String url) async {
    final hello = await _post('$url/api/hello?t=$token', {
      'name': _name,
      'system': systemLabel,
      'version': versionLabel,
      'admin': versionLabel,
      'id': deviceId,
    });
    if (hello == null) return false;
    final next = await _get('$url/api/state?t=$token');
    if (next == null) return false;
    base = url;
    state = next;
    live = true;
    final host = Uri.tryParse(url)?.host ?? '';
    status = host.startsWith('100.') ? 'Tailscale · є зв’язок' : 'Дім · є зв’язок';
    notifyListeners();
    return true;
  }

  Duration _timeout(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.startsWith('100.')) return const Duration(seconds: 6);
    if (host.startsWith('192.168.') || host.startsWith('10.')) {
      return const Duration(seconds: 2);
    }
    return const Duration(seconds: 3);
  }

  Future<Map<String, dynamic>?> _get(String url) async {
    final client = HttpClient();
    try {
      final limit = _timeout(url);
      client.connectionTimeout = limit;
      final request = await client.getUrl(Uri.parse(url)).timeout(limit);
      final response = await request.close().timeout(limit);
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _post(String url, Map<String, dynamic> payload) async {
    final client = HttpClient();
    try {
      final limit = _timeout(url);
      client.connectionTimeout = limit;
      final request = await client.postUrl(Uri.parse(url)).timeout(limit);
      final bytes = utf8.encode(jsonEncode(payload));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(limit);
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _listenBeacon() async {
    try {
      _udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
      );
      _udp!.broadcastEnabled = true;
      _udp!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = _udp!.receive();
        if (packet == null) return;
        final text = utf8.decode(packet.data, allowMalformed: true).trim();
        if (!text.startsWith('W12ADMIN1 ')) return;
        for (final part in text.split(RegExp(r'\s+'))) {
          if (part.startsWith('http://')) {
            _hints.add(part.split('?').first);
          }
        }
        if (base.isEmpty) tick();
      });
    } catch (_) {}
  }
}
