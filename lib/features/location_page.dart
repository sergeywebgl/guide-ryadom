import 'package:flutter/material.dart';

import '../domain/device_location.dart';
import 'location_controller.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key, required this.provider});
  final DeviceLocation provider;
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage>
    with WidgetsBindingObserver {
  late final c = LocationController(widget.provider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      c.cancel(clear: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Места рядом · M3.1')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Где я сейчас?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              'Определим положение один раз. Android запросит разрешение: можно выбрать примерное местоположение. Поиск достопримечательностей появится следующим шагом.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Приложение не сохраняет и не отправляет координаты. Определение остановится после результата, отмены или ухода с экрана. Вход в ChatGPT не нужен.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: c.busy ? null : c.locate,
              icon: const Icon(Icons.my_location),
              label: Text(
                c.fix == null
                    ? 'Определить местоположение'
                    : 'Обновить измерение',
              ),
            ),
            if (c.busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const Text(
                'Ожидаем разрешение и свежие координаты — до 45 секунд. На улице точность обычно лучше.',
              ),
              TextButton(
                onPressed: c.cancel,
                child: const Text('Отменить измерение'),
              ),
            ],
            if (c.issue != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(switch (c.issue!) {
                  GeoIssue.denied => 'Разрешение не получено. Можно повторить запрос или пользоваться демо.',
                  GeoIssue.blocked => 'Доступ запрещён в настройках Android. Разрешите местоположение для приложения.',
                  GeoIssue.disabled => 'Геолокация на телефоне выключена.',
                  GeoIssue.timeout => 'Свежие координаты не получены за 45 секунд. Попробуйте на открытом месте.',
                  GeoIssue.unavailable => 'Не удалось получить местоположение. Проверьте настройки телефона и повторите.',
                  GeoIssue.cancelled => 'Измерение остановлено. Для нового измерения нажмите кнопку.',
                }),
              ),
            if (c.issue == GeoIssue.blocked || c.issue == GeoIssue.denied)
              TextButton(
                onPressed: () => c.settings(app: true),
                child: const Text('Настройки разрешений'),
              ),
            if (c.issue == GeoIssue.disabled)
              TextButton(
                onPressed: () => c.settings(app: false),
                child: const Text('Настройки геолокации'),
              ),
            if (c.fix case final fix?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fix.mocked
                            ? 'Тестовые координаты Android'
                            : 'Измерение телефона',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (c.access == GeoAccess.approximate)
                        const Text(
                          'Android разрешил только примерное положение.',
                        ),
                      Text(
                        'Широта: ${fix.latitude.toStringAsFixed(5)}\nДолгота: ${fix.longitude.toStringAsFixed(5)}',
                      ),
                      Text('Заявленная точность: ±${fix.accuracy.round()} м'),
                      Text(
                        'Время измерения: ${fix.measuredAt.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
                      ),
                      const Text(
                        'Это разовый снимок, он не обновляется при движении. Точность — оценка устройства, а не гарантия.',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Демо Питерборо не связано с этими координатами. Здесь пока нет карты и списка мест.',
            ),
          ],
        ),
      ),
    ),
  );
}
