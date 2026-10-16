import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ports.dart';
import '../domain/tour.dart';
import '../features/tour_controller.dart';

const _ink = Color(0xFF233E38);
const _paper = Color(0xFFF7F3EB);
const _bronze = Color(0xFF8A6034);

class GuideApp extends StatelessWidget {
  const GuideApp({super.key, required this.controller});
  final TourController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Гид рядом',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(seedColor: _ink, surface: _paper),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
    ),
    home: _GuideHome(controller: controller),
  );
}

class _GuideHome extends StatefulWidget {
  const _GuideHome({required this.controller});
  final TourController controller;
  @override
  State<_GuideHome> createState() => _GuideHomeState();
}

class _GuideHomeState extends State<_GuideHome> {
  int tab = 0;
  TourController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    if (c.engine == null) c.load();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) * c.textScale,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _paper,
          title: const Text('Гид рядом'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 20),
              child: Icon(Icons.explore_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: c.loading
                  ? const Center(child: CircularProgressIndicator())
                  : c.error != null
                  ? _error()
                  : c.engine == null
                  ? const SizedBox.shrink()
                  : ListView(
                      key: ValueKey(tab),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        if (tab == 0)
                          ..._tour()
                        else if (tab == 1)
                          ..._route()
                        else
                          ..._settings(),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              label: 'Экскурсия',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              label: 'Маршрут',
            ),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Настройки'),
          ],
        ),
      ),
    ),
  );

  Widget _error() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.error!),
        const SizedBox(height: 16),
        FilledButton(onPressed: c.load, child: const Text('Повторить')),
      ],
    ),
  );

  List<Widget> _tour() {
    final e = c.engine!;
    final revision = e.revision;
    void act(TourAction action) {
      c.act(action, revision);
    }

    return [
      const Wrap(
        spacing: 8,
        children: [
          Chip(
            avatar: Icon(Icons.location_on_outlined, size: 18),
            label: Text('Демо: Питерборо'),
          ),
          Chip(label: Text('Без интернета')),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'СОБОР И ДВЕ КОРОЛЕВЫ',
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: _bronze, letterSpacing: 1.5),
      ),
      const SizedBox(height: 8),
      Text(
        e.completed ? 'Прогулка завершена' : e.current.title,
        style: Theme.of(context).textTheme.headlineLarge
            ?.copyWith(fontFamily: 'serif', color: _ink),
      ),
      const SizedBox(height: 16),
      if (!e.completed) ...[
        const _CathedralCard(),
        const SizedBox(height: 20),
        Text(
          '${e.index + 1} / ${e.stops.length}  ·  ${e.current.subtitle}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (e.index + 1) / e.stops.length,
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.segment.id.endsWith('detail')
                      ? 'Чуть глубже'
                      : e.segment.id.endsWith('surprise')
                      ? 'Неожиданная деталь'
                      : 'История места',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: _bronze),
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    e.segment.text,
                    style: const TextStyle(fontSize: 18, height: 1.65),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: c.explainSpeech,
                  icon: const Icon(Icons.volume_off_outlined),
                  label: const Text('Слушать · скоро'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: e.hasDetail ? () => act(TourAction.tellMore) : null,
              icon: const Icon(Icons.add),
              label: Text(e.hasDetail ? 'Подробнее' : 'Подробности прочитаны'),
            ),
            OutlinedButton.icon(
              onPressed: e.hasSurprise
                  ? () => act(TourAction.surpriseMe)
                  : null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(e.hasSurprise ? 'Удиви меня' : 'Факт прочитан'),
            ),
            OutlinedButton.icon(
              onPressed: c.explainCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Что это?'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => act(TourAction.nextStop),
          icon: const Icon(Icons.arrow_forward),
          label: Text(
            e.index == e.stops.length - 1
                ? 'Завершить прогулку'
                : 'Идём дальше',
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: e.index > 0 ? () => act(TourAction.back) : null,
              child: const Text('Назад'),
            ),
            TextButton(
              onPressed: () => act(TourAction.skip),
              child: const Text('Пропустить остановку'),
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Источники'),
          subtitle: const Text('Проверены 16.10.2026'),
          children: e.current.sources
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title),
                      SelectableText(
                        s.url.toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Копировать ссылку'),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: s.url.toString()),
                          );
                          c.showNotice(
                            'Ссылка скопирована. Откройте её в браузере при наличии интернета.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ] else ...[
        const Icon(Icons.check_circle_outline, size: 72, color: _ink),
        const SizedBox(height: 20),
        Text(
          'Вы дошли до конца демо. Пропущено остановок: ${e.skippedStops.length}.',
          style: const TextStyle(fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => act(TourAction.restart),
          child: const Text('Начать заново'),
        ),
        TextButton(
          onPressed: () => act(TourAction.back),
          child: const Text('Вернуться к последней остановке'),
        ),
      ],
      if (c.notice != null) _notice(c.notice!),
    ];
  }

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE5EBE4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: const TextStyle(height: 1.5)),
        ),
      ),
    ),
  );

  List<Widget> _route() {
    final e = c.engine!;
    final ids = c.routes.orderedStopIds(e.stops);
    return [
      Text(
        'Три истории одного места',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontFamily: 'serif'),
      ),
      _notice(
        'Схема демо, не GPS-навигация. Расстояния и проходы не рассчитаны. На месте следуйте указателям собора.',
      ),
      ...ids.map((id) {
        final i = e.stops.indexWhere((s) => s.id == id);
        final stop = e.stops[i];
        return Card(
          elevation: 0,
          color: i == e.index ? const Color(0xFFE5EBE4) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  child: Text('${i + 1}'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.subtitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.skippedStops.contains(id)
                            ? 'Пропущена'
                            : i == e.index && !e.completed
                            ? 'Вы здесь в демо'
                            : 'Остановка демо',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => tab = 0),
        child: const Text('К экскурсии'),
      ),
    ];
  }

  List<Widget> _settings() => [
    Text(
      'В своём темпе',
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(fontFamily: 'serif'),
    ),
    _notice(
      'Офлайн-демо работает без аккаунта. ChatGPT не подключён. Запросы к AI не отправляются.',
    ),
    const Text(
      'Размер текста',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    Slider(
      value: c.textScale,
      min: 1,
      max: 1.5,
      divisions: 2,
      label: '${(c.textScale * 100).round()}%',
      onChanged: c.setTextScale,
    ),
    const Text('Русский язык · системный масштаб текста также учитывается.'),
    const Divider(height: 32),
    Text(
      c.locationStatus == LocationStatus.denied
          ? 'Геолокация запрещена. Демо доступно.'
          : 'Геолокация не используется. Местоположение — демонстрационное.',
    ),
    const SizedBox(height: 16),
    const Text(
      'Камера: будет в M4.\nОзвучка: не подключена в M0.\nИстория и настройки хранятся только до закрытия приложения.',
      style: TextStyle(height: 1.8),
    ),
    const SizedBox(height: 20),
    OutlinedButton(
      onPressed: () {
        c.act(TourAction.restart, c.engine!.revision);
        c.setTextScale(1);
        setState(() => tab = 0);
      },
      child: const Text('Сбросить демо'),
    ),
  ];
}

class _CathedralCard extends StatelessWidget {
  const _CathedralCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _ArchPainter(),
              size: const Size(260, 100),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ПИТЕРБОРО',
          style: TextStyle(color: Color(0xFFE8D7B6), letterSpacing: 3),
        ),
        const SizedBox(height: 8),
        const Text(
          'Условная иллюстрация · не фотография',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD4BC8E)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.18 + i * 0.32);
      final h = i == 1 ? 8.0 : 22.0;
      final path = Path()
        ..moveTo(x - 28, 96)
        ..lineTo(x - 28, 50)
        ..quadraticBezierTo(x - 28, h + 16, x, h)
        ..quadraticBezierTo(x + 28, h + 16, x + 28, 50)
        ..lineTo(x + 28, 96);
      canvas.drawPath(path, p);
      canvas.drawLine(Offset(x - 35, 98), Offset(x + 35, 98), p);
    }
  }

  @override
  bool shouldRepaint(_ArchPainter oldDelegate) => false;
}
