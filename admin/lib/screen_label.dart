/// D-180: turns a raw telemetry `screenKey` into something a person can read.
///
/// The consumer app's navigator observer records
/// `route.settings.name ?? route.runtimeType.toString()`, and almost nothing
/// is pushed with a `RouteSettings(name:)`, so what actually arrives is a Dart
/// type with its generic attached — `MaterialPageRoute<SignInOutcome>`,
/// `_PopupMenuRoute<String?>`, `ModalBottomSheetRoute<CategoryEditResult>`.
/// The admin dashboard was printing those verbatim.
///
/// The generic is the only part that ever identifies anything: it is the type
/// the route returns, so `MaterialPageRoute<SignInOutcome>` is the sign-in
/// screen, while `MaterialPageRoute<dynamic>` is every unnamed push in the app
/// collapsed into one row. That distinction is the point of this class — a
/// row that names a screen and a row that cannot are different kinds of fact,
/// and the dashboard should not dress the second up as the first.
class ScreenLabel {
  const ScreenLabel({
    required this.name,
    required this.kind,
    required this.identifies,
    required this.raw,
  });

  /// What to show as the row's title.
  final String name;

  /// The kind of surface: 'Page', 'Dialog', 'Bottom sheet', 'Popup menu',
  /// 'Route', or empty for an explicitly named route.
  final String kind;

  /// Whether [name] actually names a screen. False when the key resolves to
  /// nothing more specific than an unattributed historical route — the caller
  /// should present the row as historical telemetry rather than as a mapped
  /// product screen.
  final bool identifies;

  /// The original telemetry key, kept so a row stays diagnosable.
  final String raw;

  static const _kindByRoute = <String, String>{
    'MaterialPageRoute': 'Page',
    'CupertinoPageRoute': 'Page',
    'PageRouteBuilder': 'Page',
    'DialogRoute': 'Dialog',
    'RawDialogRoute': 'Dialog',
    'ModalBottomSheetRoute': 'Bottom sheet',
    'PopupMenuRoute': 'Popup menu',
  };

  /// Generic arguments that carry no screen identity: they describe what the
  /// route hands back, not what it shows.
  static const _anonymousPayloads = <String>{
    'dynamic',
    'void',
    'bool',
    'int',
    'double',
    'num',
    'String',
    'String?',
    'Object',
    'Object?',
    'Null',
  };

  factory ScreenLabel.parse(String screenKey) {
    final raw = screenKey.trim();
    if (raw.isEmpty) {
      return const ScreenLabel(
        name: 'Unknown screen',
        kind: '',
        identifies: false,
        raw: '',
      );
    }

    // An explicitly named route ('/', '/setup', 'paywall') was given its name
    // deliberately, so it is already the most human thing available.
    if (!raw.contains('<')) {
      final routeKind = _kindByRoute[_stripPrivate(raw)];
      if (routeKind == null) {
        return ScreenLabel(
          name: _humanizeRouteName(raw),
          kind: '',
          identifies: true,
          raw: raw,
        );
      }
      // A bare route type with no generic identifies nothing either.
      return ScreenLabel(
        name: _unattributedName(routeKind),
        kind: routeKind,
        identifies: false,
        raw: raw,
      );
    }

    final open = raw.indexOf('<');
    final routeType = _stripPrivate(raw.substring(0, open));
    final payload = raw.endsWith('>')
        ? raw.substring(open + 1, raw.length - 1).trim()
        : raw.substring(open + 1).trim();
    final kind = _kindByRoute[routeType] ?? _humanizeType(routeType);

    if (payload.isEmpty || _anonymousPayloads.contains(payload)) {
      return ScreenLabel(
        name: _unattributedName(kind),
        kind: kind,
        identifies: false,
        raw: raw,
      );
    }

    return ScreenLabel(
      name: _humanizeType(payload),
      kind: kind,
      identifies: true,
      raw: raw,
    );
  }

  /// Dart's private types arrive with a leading underscore
  /// (`_PopupMenuRoute`); it is an implementation detail, not information.
  static String _stripPrivate(String type) =>
      type.startsWith('_') ? type.substring(1) : type;

  static String _unattributedName(String kind) => kind == 'Page'
      ? 'Unattributed page (historical)'
      : 'Historical non-screen route';

  /// `CategoryEditResult` -> `Category edit result`; a trailing `?` is
  /// nullability, which means nothing to a reader of this dashboard.
  static String _humanizeType(String type) {
    var text = _stripPrivate(type);
    while (text.endsWith('?')) {
      text = text.substring(0, text.length - 1);
    }
    // Drop suffixes that describe the plumbing rather than the screen, and
    // keep dropping: D-181 names routes after their widget, so the home
    // screen arrives as `HomeScreenWidget` and needs both taken off.
    var stripping = true;
    while (stripping) {
      stripping = false;
      for (final suffix in const [
        'Widget',
        'Route',
        'Outcome',
        'Result',
        'Screen',
      ]) {
        if (text.length > suffix.length && text.endsWith(suffix)) {
          text = text.substring(0, text.length - suffix.length);
          stripping = true;
          break;
        }
      }
    }
    if (text.isEmpty) return _stripPrivate(type);

    final words = text
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
        .replaceAllMapped(RegExp(r'(?<=[A-Z])(?=[A-Z][a-z])'), (_) => ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return _stripPrivate(type);

    final first = words.first;
    final head = first.toUpperCase() == first && first.length > 1
        ? first // an acronym stays as it is
        : '${first[0].toUpperCase()}${first.substring(1).toLowerCase()}';
    final tail = words
        .skip(1)
        .map(
          (word) => word.toUpperCase() == word && word.length > 1
              ? word
              : word.toLowerCase(),
        );
    return [head, ...tail].join(' ');
  }

  /// `/setup_habits` -> `Setup habits`; `/` -> `Home`.
  static String _humanizeRouteName(String name) {
    if (name == '/') return 'Home';
    final cleaned = name
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'[_/-]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Home';
    return _humanizeType(
      cleaned
          .replaceAll(' ', '_')
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(),
    );
  }
}
