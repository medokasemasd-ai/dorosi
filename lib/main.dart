import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'demo.dart';
import 'services/home_widget_sync.dart';
import 'services/reminders.dart';
import 'store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The web build is only a preview, so it runs on sample data in memory.
  final store = AppStore(kIsWeb ? MemoryStorage(demoJson()) : FileStorage());
  store.onChanged = (data) {
    Reminders.instance.reschedule(data);
    syncHomeWidget(data);
  };
  runApp(DorosiApp(store: store));
  // Show the data first: a problem with reminders must never keep the app from opening.
  await store.load();
  try {
    await Reminders.instance.init();
    store.onChanged?.call(store.data);
  } catch (e) {
    debugPrint('reminders unavailable: $e');
  }
}

class DorosiApp extends StatefulWidget {
  const DorosiApp({super.key, required this.store});

  final AppStore store;

  @override
  State<DorosiApp> createState() => _DorosiAppState();
}

class _DorosiAppState extends State<DorosiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reminders are planned a few weeks ahead, so top them up whenever the app is opened.
    if (state == AppLifecycleState.resumed && widget.store.loaded) {
      widget.store.onChanged?.call(widget.store.data);
    }
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  String? _look;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final s = widget.store.data.settings;
          final phoneDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
          final dark = s.themeMode == 2 || (s.themeMode == 0 && phoneDark);
          final look = '${s.themeColor}/$dark';
          if (look != _look) {
            AppColors.apply(accent: s.themeColor, dark: dark);
            // Some widgets paint with the colours directly, so redraw everything once they change.
            if (_look != null) WidgetsBinding.instance.addPostFrameCallback((_) => _redrawAll(context));
            _look = look;
          }
          return MaterialApp(
            title: 'دروسي',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Shell(),
          );
        },
      ),
    );
  }

  void _redrawAll(BuildContext context) {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (context.mounted) (context as Element).visitChildren(mark);
  }
}
