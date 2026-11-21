import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dice.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ChoreDiceApp(store: ChoreStore(prefs)));
}

class ChoreDiceApp extends StatelessWidget {
  const ChoreDiceApp({super.key, required this.store, this.random});

  final ChoreStore store;
  final Random? random;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.deepOrange;
    return MaterialApp(
      title: 'Aufgabenwürfel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true),
      home: HomePage(store: store, random: random),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store, this.random});

  final ChoreStore store;
  final Random? random;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final body = _tab == 0
            ? RollPage(store: widget.store, random: widget.random)
            : LibraryPage(store: widget.store);
        return Scaffold(
          body: SafeArea(child: body),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Aufgabe hinzufügen',
            onPressed: () => _add(repeatingDefault: _tab == 1),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.casino_outlined),
                selectedIcon: const Icon(Icons.casino),
                label: 'Würfeln (${widget.store.pot.length})',
              ),
              NavigationDestination(
                icon: const Icon(Icons.repeat),
                selectedIcon: const Icon(Icons.repeat_on),
                label: 'Bibliothek (${widget.store.library.length})',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _add({required bool repeatingDefault}) async {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => AddChoreDialog(repeatingDefault: repeatingDefault),
    );
    if (result == null) return;
    await widget.store.add(result.$1, repeating: result.$2);
  }
}

// ---------------------------------------------------------------------------
// Würfeln
// ---------------------------------------------------------------------------

class RollPage extends StatefulWidget {
  const RollPage({super.key, required this.store, this.random});

  final ChoreStore store;
  final Random? random;

  @override
  State<RollPage> createState() => _RollPageState();
}

class _RollPageState extends State<RollPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Random _random = widget.random ?? Random();
  int _face = 6;
  int _lastFaceTick = -1;
  String? _resultId;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTick);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        setState(() {});
      }
    });
  }

  void _onTick() {
    // Augen wechseln während des Wurfs, zum Ende hin immer langsamer.
    final t = Curves.easeOut.transform(_ctrl.value);
    final tick = (t * 14).floor();
    if (tick != _lastFaceTick && _ctrl.value < 1) {
      _lastFaceTick = tick;
      setState(() => _face = _random.nextInt(6) + 1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _rolling => _ctrl.isAnimating;

  void _roll() {
    if (_rolling) return;
    final chore = widget.store.roll(_random);
    if (chore == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _resultId = chore.id;
      _lastFaceTick = -1;
    });
    _ctrl.forward(from: 0);
  }

  Future<void> _complete(Chore chore) async {
    final snapshot = Chore(
        id: chore.id,
        title: chore.title,
        repeating: chore.repeating,
        inPot: true);
    setState(() => _resultId = null);
    await widget.store.complete(chore.id);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(chore.repeating
          ? '„${chore.title}“ erledigt – zurück in der Bibliothek'
          : '„${chore.title}“ erledigt'),
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () => widget.store.restore(snapshot),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pot = store.pot;
    final theme = Theme.of(context);
    final result = _resultId == null ? null : store.byId(_resultId!);
    final showResult = result != null && result.inPot && !_rolling;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              children: [
                Text('Was ist als Nächstes dran?',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: pot.isEmpty ? null : _roll,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      final t = _ctrl.value;
                      final angle = Curves.easeOutCubic.transform(t) * 4 * pi;
                      final hop = sin(t * pi * 3) * 18 * (1 - t);
                      return Transform.translate(
                        offset: Offset(0, -hop.abs()),
                        child: Transform.rotate(angle: angle, child: child),
                      );
                    },
                    child: Opacity(
                      opacity: pot.isEmpty ? 0.4 : 1,
                      child: DiceFace(value: _face, size: 140),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (pot.isEmpty)
                  _EmptyPot(store: store)
                else if (showResult)
                  _ResultCard(
                    chore: result,
                    onDone: () => _complete(result),
                    onReroll: _roll,
                  )
                else
                  FilledButton.icon(
                    key: const Key('roll'),
                    onPressed: _rolling ? null : _roll,
                    icon: const Icon(Icons.casino),
                    label: Text(_rolling ? 'Würfelt …' : 'Würfeln'),
                  ),
              ],
            ),
          ),
        ),
        if (pot.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
              child: Text('Im Topf (${pot.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ),
        SliverList.builder(
          itemCount: pot.length,
          itemBuilder: (context, i) {
            final c = pot[i];
            return Dismissible(
              key: ValueKey('pot-${c.id}'),
              background: Container(
                color: theme.colorScheme.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Icon(Icons.remove_circle_outline,
                    color: theme.colorScheme.onErrorContainer),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                final snapshot = Chore(
                    id: c.id,
                    title: c.title,
                    repeating: c.repeating,
                    inPot: true);
                if (_resultId == c.id) _resultId = null;
                store.removeFromPot(c.id);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(c.repeating
                        ? '„${c.title}“ aus dem Topf genommen'
                        : '„${c.title}“ gelöscht'),
                    action: SnackBarAction(
                      label: 'Rückgängig',
                      onPressed: () => store.restore(snapshot),
                    ),
                  ));
              },
              child: ListTile(
                leading: Icon(c.repeating ? Icons.repeat : Icons.looks_one),
                title: Text(c.title),
                selected: showResult && c.id == _resultId,
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(
      {required this.chore, required this.onDone, required this.onReroll});

  final Chore chore;
  final VoidCallback onDone;
  final VoidCallback onReroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              chore.title,
              key: const Key('result'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(chore.repeating ? 'wiederkehrend' : 'einmalig',
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('done'),
                  onPressed: onDone,
                  icon: const Icon(Icons.check),
                  label: const Text('Erledigt'),
                ),
                OutlinedButton.icon(
                  onPressed: onReroll,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Nochmal würfeln'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPot extends StatelessWidget {
  const _EmptyPot({required this.store});

  final ChoreStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Der Topf ist leer.\nFüge mit + Aufgaben hinzu.',
          textAlign: TextAlign.center,
        ),
        if (store.hasRepeatingOutsidePot) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: store.addAllRepeatingToPot,
            icon: const Icon(Icons.repeat),
            label: const Text('Wiederkehrende auffüllen'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bibliothek
// ---------------------------------------------------------------------------

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.store});

  final ChoreStore store;

  @override
  Widget build(BuildContext context) {
    final lib = store.library;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Wiederkehrende Aufgaben',
                    style: theme.textTheme.titleLarge),
              ),
              if (store.hasRepeatingOutsidePot)
                TextButton.icon(
                  onPressed: store.addAllRepeatingToPot,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Alle in den Topf'),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('Tippen, um eine Aufgabe wieder in den Topf zu legen.'),
        ),
        Expanded(
          child: lib.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Noch keine wiederkehrenden Aufgaben.\n'
                      'Z. B. „Spülmaschine ausräumen“ – mit + anlegen.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: lib.length,
                  itemBuilder: (context, i) {
                    final c = lib[i];
                    return ListTile(
                      leading: Icon(
                        c.inPot
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: c.inPot ? theme.colorScheme.primary : null,
                      ),
                      title: Text(c.title),
                      subtitle: Text(c.inPot ? 'im Topf' : 'nicht im Topf'),
                      onTap: c.inPot ? null : () => store.addToPot(c.id),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'rename') {
                            final t = await showDialog<String>(
                              context: context,
                              builder: (_) =>
                                  RenameDialog(initial: c.title),
                            );
                            if (t != null) await store.rename(c.id, t);
                          } else if (v == 'out') {
                            await store.removeFromPot(c.id);
                          } else if (v == 'delete') {
                            await store.delete(c.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'rename', child: Text('Umbenennen')),
                          if (c.inPot)
                            const PopupMenuItem(
                                value: 'out',
                                child: Text('Aus dem Topf nehmen')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Löschen')),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialoge
// ---------------------------------------------------------------------------

class AddChoreDialog extends StatefulWidget {
  const AddChoreDialog({super.key, this.repeatingDefault = false});

  final bool repeatingDefault;

  @override
  State<AddChoreDialog> createState() => _AddChoreDialogState();
}

class _AddChoreDialogState extends State<AddChoreDialog> {
  final _ctrl = TextEditingController();
  late bool _repeating = widget.repeatingDefault;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.trim().isEmpty) return;
    Navigator.pop(context, (_ctrl.text.trim(), _repeating));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Aufgabe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('title'),
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Was ist zu tun?',
              hintText: 'z. B. Glühbirne wechseln',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('repeating'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Wiederkehrend'),
            subtitle: Text(_repeating
                ? 'Bleibt nach „Erledigt“ in der Bibliothek'
                : 'Wird nach „Erledigt“ gelöscht'),
            value: _repeating,
            onChanged: (v) => setState(() => _repeating = v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(
            key: const Key('save'),
            onPressed: _submit,
            child: const Text('Hinzufügen')),
      ],
    );
  }
}

class RenameDialog extends StatefulWidget {
  const RenameDialog({super.key, required this.initial});

  final String initial;

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Umbenennen'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('Speichern')),
      ],
    );
  }
}
