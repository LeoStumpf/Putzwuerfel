import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';
import 'ui.dart';

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
    return MaterialApp(
      title: 'Putzwürfel',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(store: store, random: random),
    );
  }
}

void _snack(ScaffoldMessengerState messenger, String text,
    {String? actionLabel, VoidCallback? onAction}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 5),
      persist: false,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction!),
    ));
}

/// Wo das Menü geöffnet wurde – bestimmt, was „entfernen“ bedeutet.
enum MenuPlace { pot, library }

/// Bearbeiten-Menü für eine Aufgabe.
///
/// * Im **Topf** wirkt alles nur auf den Topf: „Aus dem Topf nehmen“
///   (wiederkehrende bleiben in der Bibliothek, einmalige sind dann weg).
/// * In der **Bibliothek** wird endgültig gelöscht.
Future<void> showChoreMenu(BuildContext context, ChoreStore store, Chore c,
    {required MenuPlace place}) async {
  final messenger = ScaffoldMessenger.of(context);
  final inPotView = place == MenuPlace.pot;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => Theme(
      data: creamTheme(),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 2),
              child: Text(c.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: K.display, fontSize: 20, color: K.ink)),
            ),
            Text(
              c.repeating ? 'Wiederkehrend' : 'Einmalig',
              style: const TextStyle(
                  color: K.green, fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _MenuItem(
              key: const Key('menu-rename'),
              icon: Icons.edit_outlined,
              title: 'Umbenennen',
              value: 'rename',
            ),
            if (inPotView && !c.repeating)
              const _MenuItem(
                key: Key('menu-lib'),
                icon: Icons.repeat,
                title: 'Zur Bibliothek hinzufügen',
                subtitle: 'Wird ab jetzt wiederkehrend',
                value: 'lib',
              ),
            if (!inPotView && !c.inPot)
              const _MenuItem(
                key: Key('menu-in'),
                icon: Icons.add_circle_outline,
                title: 'In den Topf legen',
                value: 'in',
              ),
            if (c.inPot)
              _MenuItem(
                key: const Key('menu-out'),
                icon: Icons.remove_circle_outline,
                title: 'Aus dem Topf nehmen',
                subtitle: c.repeating
                    ? 'Bleibt in der Bibliothek'
                    : 'Einmalige Aufgabe – ist danach weg',
                value: 'out',
              ),
            if (!inPotView)
              const _MenuItem(
                key: Key('menu-delete'),
                icon: Icons.delete_outline,
                title: 'Aus der Bibliothek löschen',
                subtitle: 'Endgültig – auch aus dem Topf',
                value: 'delete',
                danger: true,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  final snapshot =
      Chore(id: c.id, title: c.title, repeating: c.repeating, inPot: c.inPot);
  switch (action) {
    case 'rename':
      final t = await showDialog<String>(
        context: context,
        builder: (_) => RenameDialog(initial: c.title),
      );
      if (t != null) await store.rename(c.id, t);
    case 'lib':
      await store.makeRepeating(c.id);
      _snack(messenger, '„${c.title}“ ist jetzt in der Bibliothek');
    case 'in':
      await store.addToPot(c.id);
    case 'out':
      await store.removeFromPot(c.id);
      _snack(
          messenger,
          c.repeating
              ? '„${c.title}“ aus dem Topf genommen'
              : '„${c.title}“ entfernt',
          actionLabel: 'Rückgängig',
          onAction: () => store.restore(snapshot));
    case 'delete':
      await store.delete(c.id);
      _snack(messenger, '„${c.title}“ gelöscht',
          actionLabel: 'Rückgängig', onAction: () => store.restore(snapshot));
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? K.red : K.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700)),
      onTap: () => Navigator.pop(context, value),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: K.greenDark,
      ),
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final store = widget.store;
          final current = store.current;
          final Widget body;
          final String key;
          if (current != null) {
            body = ResultPage(store: store, chore: current);
            key = 'result-${current.id}';
          } else if (_tab == 0) {
            body = PotPage(
                store: store,
                random: widget.random,
                onOpenLibrary: () => setState(() => _tab = 1));
            key = 'pot';
          } else {
            body = LibraryPage(store: store);
            key = 'lib';
          }
          return Scaffold(
            body: SafeArea(
              bottom: current != null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(key), child: body),
              ),
            ),
            bottomNavigationBar: current != null
                ? null
                : _BottomBar(
                    tab: _tab,
                    potCount: store.pot.length,
                    libCount: store.library.length,
                    onTab: (i) => setState(() => _tab = i),
                    onAdd: () => _add(repeatingDefault: _tab == 1),
                  ),
          );
        },
      ),
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tab,
    required this.potCount,
    required this.libCount,
    required this.onTab,
    required this.onAdd,
  });

  final int tab;
  final int potCount;
  final int libCount;
  final ValueChanged<int> onTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: K.greenDark,
        border: Border(top: BorderSide(color: K.ink, width: 4)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TabButton(
                  key: const Key('tab-pot'),
                  label: 'TOPF $potCount',
                  selected: tab == 0,
                  onTap: () => onTab(0),
                ),
              ),
              const ColoredBox(color: K.ink, child: SizedBox(width: 4)),
              Expanded(
                child: _TabButton(
                  key: const Key('tab-lib'),
                  label: 'BIBLIOTHEK $libCount',
                  selected: tab == 1,
                  onTap: () => onTab(1),
                ),
              ),
              const ColoredBox(color: K.ink, child: SizedBox(width: 4)),
              Material(
                color: K.mustard,
                child: InkWell(
                  key: const Key('add'),
                  onTap: onAdd,
                  child: const SizedBox(
                    width: 80,
                    child: Icon(Icons.add,
                        size: 34,
                        color: K.ink,
                        semanticLabel: 'Aufgabe hinzufügen'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? K.cream : K.greenDark,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(
                        fontFamily: K.display,
                        fontSize: 15,
                        color: selected ? K.green : K.soft)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topf: alles Offene + „Jetzt würfeln!“
// ---------------------------------------------------------------------------

class PotPage extends StatefulWidget {
  const PotPage(
      {super.key,
      required this.store,
      required this.onOpenLibrary,
      this.random});

  final ChoreStore store;
  final VoidCallback onOpenLibrary;
  final Random? random;

  @override
  State<PotPage> createState() => _PotPageState();
}

class _PotPageState extends State<PotPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Random _random = widget.random ?? Random();

  bool get _rolling => _ctrl.isAnimating;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    if (_rolling) return;
    final chore = widget.store.roll(_random);
    if (chore == null) return;
    HapticFeedback.lightImpact();
    setState(() {});
    await _ctrl.forward(from: 0);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await widget.store.setCurrent(chore.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pot = store.pot;
    final messenger = ScaffoldMessenger.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('PUTZ-\nWÜRFEL', style: K.headline),
                ),
                Transform.rotate(
                  angle: 0.05,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: const BoxDecoration(
                      color: K.mustard,
                      border: Border.fromBorderSide(
                          BorderSide(color: K.ink, width: 3)),
                      boxShadow: [
                        BoxShadow(color: K.ink, offset: Offset(3, 3))
                      ],
                    ),
                    child: Text('${pot.length} im Topf',
                        style: const TextStyle(
                            color: K.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: GestureDetector(
              onTap: pot.isEmpty ? null : _roll,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final (slip, shake) =
                      _rolling ? Bucket.at(_ctrl.value) : (1.0, 0.0);
                  return Opacity(
                    opacity: pot.isEmpty ? 0.45 : 1,
                    child: Bucket(size: 210, slip: slip, shake: shake),
                  );
                },
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: pot.isEmpty
                ? _EmptyPot(onOpenLibrary: widget.onOpenLibrary)
                : PopButton(
                    key: const Key('roll'),
                    label: _rolling ? 'WÜRFELT …' : 'JETZT WÜRFELN!',
                    icon: Icons.auto_awesome,
                    onPressed: _rolling ? null : _roll,
                  ),
          ),
        ),
        if (pot.isNotEmpty) SliverToBoxAdapter(
          child: SectionLabel('ALLES OFFENE · ${pot.length}'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: pot.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = pot[i];
              return Dismissible(
                key: ValueKey('pot-${c.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: K.red,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.remove_circle_outline,
                      color: Colors.white),
                ),
                onDismissed: (_) {
                  final snapshot = Chore(
                      id: c.id,
                      title: c.title,
                      repeating: c.repeating,
                      inPot: true);
                  store.removeFromPot(c.id);
                  _snack(
                    messenger,
                    c.repeating
                        ? '„${c.title}“ aus dem Topf genommen'
                        : '„${c.title}“ gelöscht',
                    actionLabel: 'Rückgängig',
                    onAction: () => store.restore(snapshot),
                  );
                },
                child: ChoreRow(
                  key: ValueKey('row-${c.id}'),
                  title: c.title,
                  repeating: c.repeating,
                  onTap: () =>
                      showChoreMenu(context, store, c, place: MenuPlace.pot),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _EmptyPot extends StatelessWidget {
  const _EmptyPot({required this.onOpenLibrary});

  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Der Topf ist leer.\nLeg Aufgaben aus der Bibliothek rein\n'
          'oder füge mit + neue hinzu.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: K.soft, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 16),
        PopButton(
          key: const Key('openLib'),
          label: 'ZUR BIBLIOTHEK',
          icon: Icons.inventory_2_outlined,
          background: K.mustard,
          foreground: K.ink,
          height: 54,
          fontSize: 16,
          shadowOffset: 5,
          onPressed: onOpenLibrary,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gezogen: die Aufgabe groß, nur „Erledigt“ (+ ggf. „Zur Bibliothek“)
// ---------------------------------------------------------------------------

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.store, required this.chore});

  final ChoreStore store;
  final Chore chore;

  Future<void> _done(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = Chore(
        id: chore.id,
        title: chore.title,
        repeating: chore.repeating,
        inPot: true);
    HapticFeedback.mediumImpact();
    await store.complete(chore.id);
    if (snapshot.repeating) {
      _snack(
        messenger,
        '„${snapshot.title}“ erledigt – zurück in der Bibliothek',
        actionLabel: 'Rückgängig',
        onAction: () async {
          await store.restore(snapshot);
          await store.setCurrent(snapshot.id);
        },
      );
    } else {
      _snack(
        messenger,
        '„${snapshot.title}“ erledigt',
        actionLabel: '+ Bibliothek',
        onAction: () => store.addToLibrary(snapshot),
      );
    }
  }

  Future<void> _toLibrary(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await store.makeRepeating(chore.id);
    _snack(messenger, '„${chore.title}“ ist jetzt in der Bibliothek');
  }

  @override
  Widget build(BuildContext context) {
    final others = store.pot.where((c) => c.id != chore.id).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Bucket(size: 52),
              SizedBox(width: 10),
              Text('DAS GLÜCK SAGT:',
                  style: TextStyle(
                      fontFamily: K.display, fontSize: 18, color: K.cream)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 30, 0),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, t, child) => Transform.scale(
              scale: 0.6 + 0.4 * t,
              child: Transform.rotate(angle: -0.035 * t, child: child),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                color: K.cream,
                border:
                    Border.fromBorderSide(BorderSide(color: K.ink, width: 4)),
                boxShadow: [BoxShadow(color: K.ink, offset: Offset(8, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('JETZT DRAN',
                            style: TextStyle(
                                color: K.green,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.8)),
                      ),
                      _KindChip(repeating: chore.repeating),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    chore.title.toUpperCase(),
                    key: const Key('result'),
                    style: const TextStyle(
                        fontFamily: K.display,
                        fontSize: 36,
                        height: 1.0,
                        color: K.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: PopButton(
            key: const Key('done'),
            label: 'ERLEDIGT',
            icon: Icons.check,
            height: 66,
            fontSize: 24,
            onPressed: () => _done(context),
          ),
        ),
        if (!chore.repeating)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: OutlinedButton.icon(
              key: const Key('toLibrary'),
              onPressed: () => _toLibrary(context),
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('Zur Bibliothek hinzufügen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: K.cream,
                side: const BorderSide(color: K.cream, width: 3),
                shape: const RoundedRectangleBorder(),
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                    fontFamily: K.body,
                    fontWeight: FontWeight.w900,
                    fontSize: 15),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          child: Text(
            chore.repeating
                ? 'Keine Ausreden. Erst erledigen,\ndann wird neu gewürfelt.'
                : 'Macht die Aufgabe wiederkehrend –\nsie bleibt trotzdem jetzt dran.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: K.soft, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        if (others.isNotEmpty) ...[
          SectionLabel('AUCH NOCH IM TOPF · ${others.length}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Opacity(
              opacity: 0.7,
              child: Column(
                children: [
                  for (final c in others)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ChoreRow(
                          title: c.title,
                          repeating: c.repeating,
                          compact: true),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.repeating});

  final bool repeating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      color: repeating ? K.green : K.mustard,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (repeating) ...[
            const Icon(Icons.repeat, size: 13, color: K.cream),
            const SizedBox(width: 4),
          ],
          Text(
            repeating ? 'WIEDERKEHREND' : '1× EINMALIG',
            style: TextStyle(
                color: repeating ? K.cream : K.ink,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bibliothek: nur wiederkehrende Aufgaben
// ---------------------------------------------------------------------------

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.store});

  final ChoreStore store;

  @override
  Widget build(BuildContext context) {
    final lib = store.library;
    final inPot = lib.where((c) => c.inPot).length;
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BIBLIO-\nTHEK', style: K.headline),
                SizedBox(height: 8),
                Text(
                  'Alles, was immer wiederkommt. Antippen legt die Aufgabe '
                  'in den Topf, die drei Punkte öffnen Bearbeiten & Löschen.',
                  style: TextStyle(
                      color: K.soft, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        if (lib.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Noch keine wiederkehrenden Aufgaben.\n'
                'Z. B. „Spülmaschine ausräumen“ – mit + anlegen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: K.soft, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: SectionLabel('WIEDERKEHREND · ${lib.length}',
                trailing: '$inPot IM TOPF'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 92,
              ),
              itemCount: lib.length,
              itemBuilder: (context, i) {
                final c = lib[i];
                return _LibraryTile(
                  chore: c,
                  onTap: c.inPot ? null : () => store.addToPot(c.id),
                  onLongPress: () => showChoreMenu(context, store, c,
                      place: MenuPlace.library),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile(
      {required this.chore, required this.onTap, required this.onLongPress});

  final Chore chore;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final inPot = chore.inPot;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: inPot
                    ? const Text('IM TOPF',
                        style: TextStyle(
                            color: K.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.1))
                    : const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.add, color: K.cream, size: 20)),
              ),
              _MoreButton(
                key: ValueKey('more-${chore.id}'),
                color: inPot ? K.ink : K.cream,
                onPressed: onLongPress,
              ),
            ],
          ),
          Text(
            chore.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: inPot ? K.ink : K.cream,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.15),
          ),
        ],
      ),
    );
    final tile = inPot
        ? Container(
            decoration: const BoxDecoration(
              color: K.cream,
              border:
                  Border.fromBorderSide(BorderSide(color: K.ink, width: 3)),
              boxShadow: [BoxShadow(color: K.ink, offset: Offset(4, 4))],
            ),
            child: content,
          )
        : CustomPaint(
            painter:
                DashedBorderPainter(color: K.cream.withValues(alpha: 0.55)),
            child: content,
          );
    return Semantics(
      button: true,
      label: inPot ? 'im Topf' : 'in den Topf legen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: tile,
      ),
    );
  }
}

/// Kleiner „⋮“-Knopf zum Bearbeiten.
class _MoreButton extends StatelessWidget {
  const _MoreButton({super.key, required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bearbeiten',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(Icons.more_vert, color: color, size: 20),
        ),
      ),
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
    return Theme(
      data: creamTheme(),
      child: AlertDialog(
        title: const Text('NEUE AUFGABE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('title'),
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: K.ink, fontWeight: FontWeight.w700, fontSize: 16),
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
              title: Text(_repeating ? 'Wiederkehrend' : 'Einmalig',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_repeating
                  ? 'Kommt nach „Erledigt“ zurück in die Bibliothek'
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
      ),
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
    return Theme(
      data: creamTheme(),
      child: AlertDialog(
        title: const Text('UMBENENNEN'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: K.ink, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}
