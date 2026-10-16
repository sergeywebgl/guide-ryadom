import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_controller.dart';

class AccountSection extends StatefulWidget {
  const AccountSection({super.key, required this.controller});
  final AuthController controller;
  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  AuthController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.initialize();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Аккаунт ChatGPT · M1.5',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(switch (c.state) {
                AccountState.disconnected => 'Не подключён',
                AccountState.connecting =>
                  'Подключение через системный браузер…',
                AccountState.connected => 'Подключён',
                AccountState.error => 'Ошибка подключения',
              }),
              if (c.account != null) ...[
                const SizedBox(height: 8),
                SelectableText(c.account!.label),
                Text(
                  c.inferenceAllowed
                      ? 'Использование плана разрешено. Доступ модели подтверждается только полным ответом.'
                      : 'Вход выполнен, но GPT-запросы не разрешены выданными scopes.',
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Офлайн-экскурсия доступна без входа. Подключение использует ваш план ChatGPT; доступность зависит от аккаунта и правил OpenAI. API-ключ не требуется.',
              ),
              if (c.busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                if (c.state == AccountState.connecting)
                  const Text(
                    'После ответа в браузере вернитесь сюда: обмен кода начнётся только после возврата. Ожидание callback — до 3 минут, возврата — до 1 минуты.',
                  ),
                TextButton(onPressed: c.cancel, child: const Text('Отменить')),
              ] else if (c.account == null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => c.connect(),
                  child: const Text('Подключить ChatGPT'),
                ),
                const Text(
                  'Continue with ChatGPT',
                  style: TextStyle(fontSize: 12),
                ),
                for (final account in c.provider.registrations)
                  OutlinedButton(
                    onPressed: () => c.connect(clientId: account.clientId),
                    child: Text('Войти снова: ${account.label}'),
                  ),
                if (c.state == AccountState.error)
                  TextButton(
                    onPressed: c.disconnect,
                    child: const Text('Очистить локальную сессию'),
                  ),
              ] else ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: c.disconnect,
                  child: const Text('Отключить аккаунт'),
                ),
                if (!c.inferenceAllowed)
                  TextButton(
                    onPressed: () => c.connect(clientId: c.account!.clientId),
                    child: const Text('Повторить вход для разрешения плана'),
                  ),
              ],
              if (c.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(liveRegion: true, child: Text(c.message!)),
                ),
              if (c.failure != null) ...[
                if (c.failure!.stageLabel != null)
                  Text('Этап: ${c.failure!.stageLabel}'),
                SelectableText('Диагностика: ${c.failure!.diagnostic}'),
                TextButton(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: c.failure!.diagnostic),
                  ),
                  child: const Text('Копировать код ошибки'),
                ),
              ],
              if (c.account != null && c.inferenceAllowed) ...[
                const Divider(height: 28),
                Text(
                  'Проверка GPT',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Один сетевой запрос по вашему нажатию. Факт из ответа не проверен — это тест связи, не экскурсионный материал.',
                ),
                if (c.models.isEmpty)
                  TextButton(
                    onPressed: c.busy ? null : c.loadModels,
                    child: const Text('Загрузить модели'),
                  ),
                if (c.models.isNotEmpty)
                  DropdownButton<String>(
                    isExpanded: true,
                    value: c.selectedModel,
                    items: c.models
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.slug,
                            child: Text(
                              m.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: c.busy ? null : c.selectModel,
                  ),
                const Text(
                  '«Расскажи один интересный и общеизвестный факт о Питерборском соборе в двух предложениях.»',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: c.busy || c.selectedModel == null
                      ? null
                      : c.runProbe,
                  child: const Text('Отправить тестовый запрос'),
                ),
                if (c.text.isNotEmpty || c.completed) ...[
                  const SizedBox(height: 12),
                  Text(
                    c.completed
                        ? 'Ответ завершён · response.completed'
                        : 'Частичный ответ — успех не подтверждён',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(c.text),
                ],
              ],
              const SizedBox(height: 12),
              const Text(
                'Лимиты плана и доступ приложения: chatgpt.com/settings/usage',
              ),
              TextButton(
                onPressed: () => Clipboard.setData(
                  const ClipboardData(
                    text: 'https://chatgpt.com/settings/usage',
                  ),
                ),
                child: const Text('Копировать ссылку Usage'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
