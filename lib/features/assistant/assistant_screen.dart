import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_exception.dart';
import '../../data/lapticon_api.dart';

class _Message {
  const _Message(this.text, {this.mine = false, this.failed = false});

  final String text;
  final bool mine;
  final bool failed;
}

const _suggestions = [
  '¿Cómo envío una encomienda?',
  '¿Cómo funciona la calificación?',
  '¿Qué pasa si mi encomienda vence?',
];

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _messages = <_Message>[];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _messages.insert(0, _Message(text, mine: true));
      _busy = true;
    });
    _Message reply;
    try {
      final answer = await context.read<LapticonApi>().preguntarAsistente(text);
      reply = _Message(
        answer.isEmpty ? 'No tengo una respuesta para eso.' : answer,
      );
    } on ApiException catch (error) {
      reply = _Message(
        error.kind == ApiErrorKind.server
            ? 'El asistente no está disponible ahora. Intenta más tarde.'
            : error.message,
        failed: true,
      );
    }
    if (mounted) {
      setState(() {
        _messages.insert(0, reply);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty && !_busy
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          '¿En qué te ayudo?',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pregunta sobre encomiendas, viajes y calificaciones.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final suggestion in _suggestions)
                              ActionChip(
                                label: Text(suggestion),
                                onPressed: () => _send(suggestion),
                              ),
                          ],
                        ),
                      ],
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length + (_busy ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_busy && index == 0) return const _TypingBubble();
                        final message = _messages[index - (_busy ? 1 : 0)];
                        return _Bubble(message);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu pregunta',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = message.mine
        ? (scheme.primary, scheme.onPrimary)
        : message.failed
            ? (scheme.errorContainer, scheme.onErrorContainer)
            : (scheme.surfaceContainerHigh, scheme.onSurface);

    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(color: foreground),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'El asistente está escribiendo',
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        ),
      );
}
