import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/app_colors.dart';
import '../core/camo_button.dart';
import '../core/user_config.dart';
import '../services/db_service.dart';
import '../services/last_action.dart';
import '../services/qr_parser.dart';
import '../core/tactical_ui.dart';
import '../core/fun_moments.dart';
import 'transfer_sheet.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.dataMatrix,
    ],
  );
  bool _busy = false;
  String? _status;
  String? _personName;
  String? _ignoreCode;
  DateTime? _ignoreUntil;

  @override
  void initState() {
    super.initState();
    final last = UserConfig().lastIssuePerson.trim();
    if (last.isNotEmpty) _personName = last;
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (code == null) return;
    final raw = code.trim();
    if (_ignoreCode == raw &&
        _ignoreUntil != null &&
        DateTime.now().isBefore(_ignoreUntil!)) {
      return;
    }

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _camera.stop();
    } catch (_) {}
    await _handleCode(raw);
  }

  Future<void> _handleCode(String raw) async {
    final payload = QrParser.parse(raw);
    final items = await DBService().getAllItems();
    final bound = await DBService().findQrBinding(raw);
    final match = QrParser.match(payload, items,
        boundUid: bound?.uid, boundLocalId: bound?.localId);

    if (!mounted) return;
    if (match == null) {
      await _showUnknown(payload, items);
    } else {
      await _showMatch(match);
    }
    if (mounted) {
      _ignoreCode = raw;
      _ignoreUntil = DateTime.now().add(const Duration(milliseconds: 2200));
      setState(() => _busy = false);
      try {
        await _camera.start();
      } catch (_) {}
    }
  }

  Future<void> _showUnknown(
      QrPayload payload, List<Map<String, dynamic>> items) async {
    Map<String, dynamic>? picked;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(builder: (ctx, setModal) {
          final filtered = items.where((i) {
            final hay =
                '${i['name']} ${i['warehouse']} ${i['category']} ${i['location']}'
                    .toLowerCase();
            return q.trim().isEmpty || hay.contains(q.toLowerCase());
          }).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 14),
                  Text('Це заводський код, не назва',
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'На мішку написані лише цифри. Один раз вибери, що це за річ зі складу — далі цей код одразу відкриє назву, розмір і кнопки.',
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: AppColors.cardDeco(),
                    child: Text('Код: ${payload.raw}',
                        style: TextStyle(
                            color: AppColors.accentBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: items.length > 8,
                    onChanged: (v) => setModal(() => q = v),
                    style: TextStyle(color: AppColors.textMain),
                    decoration: InputDecoration(
                      hintText: 'Пошук: куртка, берці, розмір...',
                      hintStyle: TextStyle(color: AppColors.muted),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'Список складу порожній.\nСпочатку відкрий вкладку Склад або синхронізуй на Огляді.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.muted, height: 1.4),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              final sizes = QrParser.sizesOf(item);
                              final sizeHint = sizes.isEmpty
                                  ? 'без розміру'
                                  : sizes.keys.take(6).join(', ');
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${item['name']}',
                                    style: TextStyle(
                                        color: AppColors.textMain,
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                    '${item['warehouse'] ?? ''}  •  ${item['total'] ?? 0} шт  •  $sizeHint',
                                    style: TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                                trailing: Icon(Icons.link_rounded,
                                    color: AppColors.accent),
                                onTap: () {
                                  picked = item;
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                  CamoButton(
                    label: 'Відхилити',
                    tone: CamoTone.deep,
                    compact: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (picked != null) {
      await DBService().bindQr(payload.raw, '${picked!['uid'] ?? ''}',
          localId: picked!['id'] as int?);
      if (!mounted) return;
      await _showMatch(QrMatch(
        item: picked!,
        payload: payload,
        sizeKey: QrParser.sizesOf(picked!).length == 1
            ? QrParser.sizesOf(picked!).keys.first.toString()
            : null,
      ));
    }
  }

  Future<void> _showMatch(QrMatch match) async {
    String? sizeKey = match.sizeKey;
    final sizes = QrParser.sizesOf(match.item);
    final sizeKeys = QrParser.realSizeKeys(sizes);
    final needsSize = QrParser.needsSizePick(match.item);
    if (!needsSize) sizeKey = null;
    if (sizeKey != null && !sizeKeys.contains(sizeKey) && sizeKeys.isNotEmpty) {
      sizeKey = null;
    }
    final online = await DBService().hasInternet();
    final customCtrl = TextEditingController();

    if (!mounted) return;
    final delta = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          final locked = needsSize && (sizeKey ?? '').isEmpty;
          final stock = sizeKey == null
              ? (int.tryParse('${match.item['total']}') ?? 0)
              : (int.tryParse('${sizes[sizeKey]}') ?? 0);
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 14),
                  Text('${match.item['name']}',
                      style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 20)),
                  const SizedBox(height: 6),
                  Text(
                      '${match.item['warehouse'] ?? ''}  •  ${match.item['category'] ?? ''}'
                      '${_personName != null && _personName!.isNotEmpty ? '  •  кому: $_personName' : ''}',
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _infoChip('Розмір',
                          sizeKey ?? (needsSize ? 'не обрано' : 'без розміру')),
                      const SizedBox(width: 8),
                      _infoChip('На складі', locked ? '—' : '$stock шт'),
                    ],
                  ),
                  if (needsSize) ...[
                    const SizedBox(height: 14),
                    Text(
                      'На штрихкоді немає розміру. Вибери його — інакше не збережу.',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    if (sizeKeys.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sizeKeys.map((key) {
                          final on = sizeKey == key;
                          final qty = int.tryParse('${sizes[key]}') ?? 0;
                          return GestureDetector(
                            onTap: () => setModal(() => sizeKey = key),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 64),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: on
                                    ? AppColors.accent.withOpacity(0.18)
                                    : AppColors.bg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: on
                                        ? AppColors.accent
                                        : AppColors.border,
                                    width: on ? 2 : 1),
                              ),
                              child: Column(
                                children: [
                                  Text(key,
                                      style: TextStyle(
                                          color: on
                                              ? AppColors.accent
                                              : AppColors.textMain,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text('$qty шт',
                                      style: TextStyle(
                                          color: AppColors.muted, fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: customCtrl,
                      style: TextStyle(color: AppColors.textMain),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: sizeKeys.isEmpty
                            ? 'Введи розмір, наприклад 50 або 50/4'
                            : 'Інший розмір, якщо немає в списку',
                        hintStyle:
                            TextStyle(color: AppColors.muted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none),
                      ),
                      onChanged: (v) {
                        final t = v.trim();
                        setModal(() => sizeKey = t.isEmpty ? null : t);
                      },
                    ),
                  ],
                  if (!online) ...[
                    const SizedBox(height: 12),
                    Text(
                        'Немає мережі — збережу на телефоні і відправлю, щойно з\'явиться інтернет.',
                        style:
                            TextStyle(color: AppColors.warning, fontSize: 12)),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: CamoButton(
                          label: 'Відхилити',
                          tone: CamoTone.deep,
                          compact: true,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CamoButton(
                          label: 'Змінити\nкількість',
                          tone: CamoTone.khaki,
                          compact: true,
                          onPressed: locked
                              ? null
                              : () async {
                                  final d = await _askQty(ctx, stock);
                                  if (d == null || d == 0) return;
                                  Navigator.pop(ctx, d);
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CamoButton(
                          label: locked ? 'Вибери\nрозмір' : 'Підтвердити',
                          tone: CamoTone.olive,
                          compact: true,
                          onPressed:
                              locked ? null : () => Navigator.pop(ctx, -1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CamoButton(
                    label: 'На інший склад',
                    icon: Icons.swap_horiz_rounded,
                    tone: CamoTone.brown,
                    onPressed: () => Navigator.pop(ctx, 'transfer'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    customCtrl.dispose();
    if (delta == 'transfer') {
      if (!mounted) return;
      await TransferSheet.show(context,
          item: match.item, preselectedSize: sizeKey);
      return;
    }
    if (delta is! int || delta == 0) return;
    if (needsSize && (sizeKey ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Спочатку вибери розмір'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    final res = await DBService().applyStockDelta(
      localId: match.item['id'] as int,
      sizeKey: sizeKey,
      delta: delta,
      issuedTo: delta < 0 ? _personName : null,
    );
    if (!mounted) return;
    final error = res.startsWith('Помилка');
    if (!error) {
      LastAction.remember(LastStockAction(
        localId: match.item['id'] as int,
        sizeKey: sizeKey,
        delta: delta,
        message: res,
      ));
      final hits = await UserConfig().bumpTodayHits();
      if (mounted) {
        final mile = FunCopy.milestone(hits);
        await FunStamp.show(
          context,
          title: mile ?? (delta < 0 ? 'Видано' : 'Прийнято'),
          hint: FunCopy.afterScan(delta < 0),
          icon: mile != null
              ? Icons.local_fire_department_rounded
              : (delta < 0
                  ? Icons.outbox_rounded
                  : Icons.move_to_inbox_rounded),
        );
      }
    }
    if (!mounted) return;
    setState(() => _status = res);
    LastAction.showSnack(context, res, error: error);
  }

  Future<int?> _askQty(BuildContext ctx, int stock) async {
    final ctrl = TextEditingController(text: '1');
    bool issue = true;
    return showDialog<int>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDlg) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Змінити кількість',
              style: TextStyle(color: AppColors.textMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                ChoiceChip(
                  label: const Text('Видати'),
                  selected: issue,
                  selectedColor: AppColors.danger.withOpacity(0.3),
                  onSelected: (_) => setDlg(() => issue = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Прийняти'),
                  selected: !issue,
                  selectedColor: AppColors.accent.withOpacity(0.3),
                  onSelected: (_) => setDlg(() => issue = false),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: AppColors.textMain, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text('Зараз на складі: $stock',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          actions: [
            CamoButton(
              label: 'Скасувати',
              tone: CamoTone.deep,
              compact: true,
              onPressed: () => Navigator.pop(dCtx),
            ),
            CamoButton(
              label: 'Гаразд',
              tone: CamoTone.olive,
              compact: true,
              onPressed: () {
                final n = int.tryParse(ctrl.text) ?? 0;
                Navigator.pop(dCtx, issue ? -n.abs() : n.abs());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPerson() async {
    final wasBusy = _busy;
    setState(() => _busy = true);
    String q = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DBService().getPersonnel(query: q),
            builder: (ctx, snap) {
              final people = snap.data ?? [];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(8)))),
                      const SizedBox(height: 14),
                      Text('Кому видаємо?',
                          style: TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                          'Список з довідника W1.2. Можна додати прізвище прямо тут.',
                          style: TextStyle(color: AppColors.muted, height: 1.3)),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setModal(() => q = v),
                        style: TextStyle(color: AppColors.textMain),
                        decoration: InputDecoration(
                          hintText: 'Пошук ПІБ або підрозділ...',
                          hintStyle: TextStyle(color: AppColors.muted),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: AppColors.muted),
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_off_outlined,
                            color: AppColors.muted),
                        title: Text('Без прізвища',
                            style: TextStyle(color: AppColors.muted)),
                        onTap: () {
                          _personName = null;
                          UserConfig().setLastIssuePerson('');
                          Navigator.pop(ctx);
                        },
                      ),
                      Expanded(
                        child: people.isEmpty
                            ? Center(
                                child: Text(
                                  q.trim().isEmpty
                                      ? 'Список порожній. Додай прізвище нижче або синхронізуй W1.2 на ПК.'
                                      : 'Нікого не знайдено',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              )
                            : ListView.builder(
                                itemCount: people.length,
                                itemBuilder: (_, i) {
                                  final p = people[i];
                                  final name = '${p['full_name']}';
                                  final unit = '${p['unit'] ?? ''}';
                                  final rank = '${p['rank'] ?? ''}';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.person_rounded,
                                        color: AppColors.accent),
                                    title: Text(name,
                                        style: TextStyle(
                                            color: AppColors.textMain,
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text(
                                        [rank, unit]
                                            .where((e) => e.trim().isNotEmpty)
                                            .join('  •  '),
                                        style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12)),
                                    onTap: () {
                                      _personName = name;
                                      UserConfig().setLastIssuePerson(name);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              ),
                      ),
                      CamoButton(
                        label: q.trim().length < 2
                            ? 'Введи ПІБ у пошук, щоб додати'
                            : 'Додати «${q.trim()}»',
                        icon: Icons.person_add_alt_1_rounded,
                        tone: CamoTone.moss,
                        onPressed: () async {
                          final name = q.trim();
                          if (name.length < 2) return;
                          await DBService().addPerson(fullName: name);
                          _personName = name;
                          UserConfig().setLastIssuePerson(name);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    );
    if (mounted) setState(() => _busy = wasBusy);
  }

  Widget _infoChip(String k, String v) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppColors.cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k,
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(v,
                style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1714),
      appBar: TacAppBar(
        title: 'Сканер',
        code: 'Сканер',
        actions: [
          ValueListenableBuilder(
            valueListenable: _camera,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: 'Ліхтарик',
                onPressed: () => _camera.toggleTorch(),
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: on ? const Color(0xFFE0A106) : AppColors.accent,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Скасувати останнє',
            onPressed: LastAction.current == null
                ? null
                : () async {
                    final res = await LastAction.undo();
                    if (!mounted) return;
                    setState(() => _status = res);
                    LastAction.showSnack(context, res,
                        error: res.startsWith('Помилка'));
                  },
            icon: const Icon(Icons.undo_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),
          Align(
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(250, 250),
              painter: _ScanHudPainter(),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: GestureDetector(
              onTap: _pickPerson,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1714).withOpacity(0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC45C26)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded,
                        color: _personName == null
                            ? Colors.white70
                            : const Color(0xFFC45C26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _personName == null || _personName!.isEmpty
                            ? 'Кому: ще нікому  (натисни)'
                            : 'Кому: $_personName',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 36,
            child: Text(
              _status ?? FunCopy.scanIdle(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFE6DFC8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFFE8DFD4);
    final p = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    const l = 28.0;
    final r = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawLine(r.topLeft, Offset(r.left + l, r.top), p);
    canvas.drawLine(r.topLeft, Offset(r.left, r.top + l), p);
    canvas.drawLine(r.topRight, Offset(r.right - l, r.top), p);
    canvas.drawLine(r.topRight, Offset(r.right, r.top + l), p);
    canvas.drawLine(r.bottomLeft, Offset(r.left + l, r.bottom), p);
    canvas.drawLine(r.bottomLeft, Offset(r.left, r.bottom - l), p);
    canvas.drawLine(r.bottomRight, Offset(r.right - l, r.bottom), p);
    canvas.drawLine(r.bottomRight, Offset(r.right, r.bottom - l), p);
    final mid = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(mid.dx - 16, mid.dy), Offset(mid.dx + 16, mid.dy), p);
    canvas.drawLine(Offset(mid.dx, mid.dy - 16), Offset(mid.dx, mid.dy + 16), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
