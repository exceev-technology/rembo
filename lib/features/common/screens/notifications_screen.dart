import 'package:flutter/material.dart';

import '../../../core/widgets/rembo_widgets.dart';
import '../demo_session.dart';

class DemoNotification {
  DemoNotification(this.title, this.body, this.when, {this.unread = true});
  final String title;
  final String body;
  final String when;
  bool unread;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static const loadingDelay = Duration(milliseconds: 800);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<DemoNotification>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _failed = false;
    });
    await Future<void>.delayed(NotificationsScreen.loadingDelay);
    if (!mounted) return;
    setState(() {
      if (demoOffline.value) {
        _failed = true;
      } else {
        _items = [
          DemoNotification(
            'Dépense approuvée',
            'Le Zellige · Rabat — 380,00 MAD a été approuvée par Nadia Tazi.',
            'Il y a 2 h',
          ),
          DemoNotification(
            'Justificatif à compléter',
            'Ajoutez le motif de la dépense Train Al Boraq.',
            'Hier',
          ),
          DemoNotification(
            'Dépense rejetée',
            'Boutique Cadeaux Fès : cadeau client hors politique.',
            '22 oct.',
            unread: false,
          ),
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final unread = items?.where((n) => n.unread).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items != null && items.isNotEmpty)
            PopupMenuButton<String>(
              key: const ValueKey('notifications-menu'),
              tooltip: 'Actions',
              onSelected: (action) {
                setState(() {
                  if (action == 'read') {
                    for (final n in items) {
                      n.unread = false;
                    }
                  } else {
                    items.clear();
                  }
                });
                showRemboSnackBar(
                  context,
                  action == 'read'
                      ? 'Notifications marquées comme lues'
                      : 'Notifications effacées',
                );
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  key: ValueKey('mark-read'),
                  value: 'read',
                  child: Text('Tout marquer comme lu'),
                ),
                PopupMenuItem(
                  key: ValueKey('clear-all'),
                  value: 'clear',
                  child: Text('Tout effacer'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder(
              valueListenable: demoOffline,
              builder: (_, offline, _) =>
                  offline ? const OfflineBanner() : const SizedBox.shrink(),
            ),
            Expanded(
              child: _failed
                  ? ErrorState(
                      title: 'Notifications indisponibles',
                      message:
                          'Pas de connexion internet. Réessayez une fois '
                          'reconnecté.',
                      onRetry: _load,
                    )
                  : items == null
                  ? const LoadingState(message: 'Chargement des notifications…')
                  : items.isEmpty
                  ? const EmptyState.noNotifications()
                  : ListView(
                      padding: const EdgeInsets.all(RemboSpace.xl),
                      children: [
                        Text(
                          unread == 0
                              ? 'Tout est lu.'
                              : '$unread non lue${unread > 1 ? 's' : ''}',
                          key: const ValueKey('unread-count'),
                          style: RemboText.caption,
                        ),
                        const SizedBox(height: RemboSpace.md),
                        for (final n in items) ...[
                          Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(
                                RemboSpace.lg,
                              ),
                              leading: Icon(
                                n.unread ? Icons.circle : Icons.circle_outlined,
                                size: 12,
                                color: n.unread
                                    ? RemboColors.indigo
                                    : RemboColors.border,
                                semanticLabel: n.unread ? 'Non lue' : 'Lue',
                              ),
                              title: Text(n.title, style: RemboText.subtitle),
                              subtitle: Text(
                                '${n.body}\n${n.when}',
                                style: RemboText.caption,
                              ),
                              onTap: () => setState(() => n.unread = false),
                            ),
                          ),
                          const SizedBox(height: RemboSpace.md),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
