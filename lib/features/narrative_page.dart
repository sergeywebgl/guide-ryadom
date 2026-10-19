import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/narrative.dart';
import 'auth_controller.dart';
import 'narrative_controller.dart';

class NarrativePage extends StatefulWidget {
  const NarrativePage({super.key, required this.auth});
  final AuthController auth;
  @override
  State<NarrativePage> createState() => _NarrativePageState();
}

class _NarrativePageState extends State<NarrativePage> {
  late final c = NarrativeController(widget.auth);
  @override
  void initState() {
    super.initState();
    widget.auth.initialize();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, widget.auth]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('История с GPT · M2')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Питерборский собор',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              'Экспериментальный рассказ по отобранным фактам. Каждый запрос использует ваш план ChatGPT. GPS не используется.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Источники проверены 19.10.2026. Приложение проверяет ссылки и ID фактов; точность пересказа ИИ требует вашей оценки.',
            ),
            if (!widget.auth.inferenceAllowed)
              const Text(
                'Сначала подключите ChatGPT в настройках основного экрана.',
              ),
            if (widget.auth.inferenceAllowed && widget.auth.models.isEmpty)
              TextButton(
                onPressed: widget.auth.busy ? null : widget.auth.loadModels,
                child: const Text('Загрузить модели'),
              ),
            if (widget.auth.models.isNotEmpty)
              DropdownButton<String>(
                isExpanded: true,
                value: widget.auth.selectedModel,
                items: widget.auth.models
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.slug,
                        child: Text(m.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: c.busy || widget.auth.busy
                    ? null
                    : widget.auth.selectModel,
              ),
            if (widget.auth.message != null) Text(widget.auth.message!),
            for (final segment in c.history)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(segment.text),
                      const SizedBox(height: 8),
                      const Text('Источники фактов'),
                      for (final source in segment.sourceIds)
                        TextButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: evidenceSources[source]!),
                          ),
                          child: Text(
                            source == 'history'
                                ? 'История собора — копировать ссылку'
                                : 'Архитектура — копировать ссылку',
                          ),
                        ),
                      ExpansionTile(
                        title: const Text('Факты для сверки'),
                        children: [
                          for (final fact in cathedralClaims.where(
                            (f) => segment.claimIds.contains(f.id),
                          ))
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(fact.fact),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (c.busy) ...[
              const LinearProgressIndicator(),
              Text(
                'Получаем рассказ: ${c.received} символов. Покажем после завершения и проверки.',
              ),
              TextButton(
                onPressed: c.cancel,
                child: const Text('Отменить рассказ'),
              ),
            ],
            if (c.error != null) Text(c.error!, semanticsLabel: c.error),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in NarrativeAction.values)
                  FilledButton(
                    onPressed:
                        c.busy ||
                            widget.auth.busy ||
                            !widget.auth.inferenceAllowed ||
                            widget.auth.selectedModel == null ||
                            !c.available(action) ||
                            (action != NarrativeAction.intro &&
                                c.history.isEmpty)
                        ? null
                        : () => c.generate(action),
                    child: Text(switch (action) {
                      NarrativeAction.intro => 'Начать рассказ',
                      NarrativeAction.more => 'Подробнее',
                      NarrativeAction.surprise => 'Удиви меня',
                    }),
                  ),
              ],
            ),
            if (c.consumed.length == cathedralClaims.length)
              const Text(
                'Все подготовленные факты рассказаны. Новых проверенных фактов для этой остановки пока нет.',
              ),
            const Text(
              'При закрытии этого экрана история сбрасывается. Офлайн-демо доступно на предыдущем экране.',
            ),
            if (c.trace != null)
              ExpansionTile(
                title: const Text('Диагностика рассказа'),
                children: [
                  TextButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: c.trace!.report)),
                    child: const Text('Копировать отчёт рассказа'),
                  ),
                  SelectableText(
                    c.trace!.report,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
