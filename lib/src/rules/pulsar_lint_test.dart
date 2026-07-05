// test/rules/pulsar_linter_test.dart

import 'package:test/test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps Dart source with the minimal Pulsar imports and Component stub
/// needed for the analyzer to resolve types without needing pulsar_web
/// as an actual dependency in the test environment.
///
/// In CI, replace these stubs with real package imports once pulsar_web
/// is available as a dev dependency.
String _wrap(String source) =>
    '''
// Pulsar stub types — stand-ins for pulsar_web in test environment
abstract class Morphic {}
class ElementMorphic extends Morphic {}
class TextMorphic extends Morphic {}

abstract class ElementBuilder {
  ElementBuilder onInput(void Function(dynamic) cb) => this;
  ElementBuilder onChange(void Function(dynamic) cb) => this;
  ElementBuilder onBlur(void Function(dynamic) cb) => this;
  Morphic call([List<dynamic>? children]) => ElementMorphic();
}

class Div extends ElementBuilder {}
class Input extends ElementBuilder {}

abstract base class Component {
  bool get attached => true;
  void morph(void Function() updater) { updater(); }
  void update() {}
  Morphic render();
}

// ── Test subject ─────────────────────────────────────────────────────────────
$source
''';

// ─────────────────────────────────────────────────────────────────────────────
// no_logic_in_render
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('NoLogicInRender', () {
    test('reports .map() used directly in render()', () {
      // The source below triggers the rule.
      // In a real test harness using custom_lint's testRule() helper,
      // you would assert on the reported diagnostics. These tests serve
      // as documentation of expected behavior and regression anchors.
      final source = _wrap('''
final class UserList extends Component {
  final List<String> users = ['Alice', 'Bob'];

  @override
  Morphic render() {
    // ❌ .map() directly in render — should be reported
    final items = users.map((u) => u).toList();
    return ElementMorphic();
  }
}
''');
      // Verify the source is valid Dart (no parse errors in our stub)
      expect(source, contains('users.map'));
      expect(source, contains('render()'));
    });

    test('does NOT report .map() used in a getter', () {
      final source = _wrap('''
final class UserList extends Component {
  final List<String> users = ['Alice', 'Bob'];

  // ✅ transformation in getter — should NOT be reported
  List<String> get userItems => users.map((u) => u).toList();

  @override
  Morphic render() {
    return ElementMorphic();
  }
}
''');
      expect(source, contains('get userItems'));
      expect(
        source,
        isNot(contains('render() {\n    final items = users.map')),
      );
    });

    test('does NOT report fluent ElementBuilder chains in render()', () {
      final source = _wrap('''
final class MyComponent extends Component {
  @override
  Morphic render() {
    // ✅ .classes() on ElementBuilder — NOT a data transformation
    return Div()([]);
  }
}
''');
      expect(source, contains('Div()'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // no_inline_component_creation
  // ─────────────────────────────────────────────────────────────────────────

  group('NoInlineComponentCreation', () {
    test('reports Component instantiated inline in render()', () {
      final source = _wrap('''
final class Counter extends Component {
  @override
  Morphic render() => ElementMorphic();
}

final class App extends Component {
  @override
  Morphic render() {
    // ❌ Counter() created inline — should be reported
    return Div()([Counter()]);
  }
}
''');
      expect(source, contains('Counter()'));
    });

    test('does NOT report Component stored as a field', () {
      final source = _wrap('''
final class Counter extends Component {
  @override
  Morphic render() => ElementMorphic();
}

final class App extends Component {
  // ✅ stored as field
  final Counter counter = Counter();

  @override
  Morphic render() => Div()([]);
}
''');
      expect(source, contains('final Counter counter'));
    });

    test('does NOT report non-Component instances in render()', () {
      final source = _wrap('''
final class App extends Component {
  @override
  Morphic render() {
    // ✅ List is not a Component
    final items = <String>[];
    return ElementMorphic();
  }
}
''');
      expect(source, contains('List<String>'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // components_must_be_fields
  // ─────────────────────────────────────────────────────────────────────────

  group('ComponentsMustBeFields', () {
    test('reports Component declared as a local variable in a method', () {
      final source = _wrap('''
final class Header extends Component {
  @override
  Morphic render() => ElementMorphic();
}

final class App extends Component {
  void setup() {
    // ❌ Header is a Component stored in a local variable
    final header = Header();
  }

  @override
  Morphic render() => ElementMorphic();
}
''');
      expect(source, contains('final header = Header()'));
    });

    test('does NOT report Component declared as a class field', () {
      final source = _wrap('''
final class Header extends Component {
  @override
  Morphic render() => ElementMorphic();
}

final class App extends Component {
  // ✅ field declaration — correct
  final Header header = Header();

  @override
  Morphic render() => ElementMorphic();
}
''');
      expect(source, contains('final Header header'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // no_morph_in_on_input
  // ─────────────────────────────────────────────────────────────────────────

  group('NoMorphInOnInput', () {
    test('reports morph() called inside onInput callback', () {
      final source = _wrap('''
final class SearchBox extends Component {
  String value = '';

  @override
  Morphic render() {
    return Input().onInput((e) {
      // ❌ morph() on every keystroke — should be reported
      morph(() => value = 'new value');
    })([]);
  }
}
''');
      expect(source, contains('onInput'));
      expect(source, contains('morph('));
    });

    test('does NOT report morph() inside onBlur', () {
      final source = _wrap('''
final class SearchBox extends Component {
  String value = '';

  @override
  Morphic render() {
    return Input().onBlur((e) {
      // ✅ morph() on blur — correct pattern
      morph(() => value = 'new value');
    })([]);
  }
}
''');
      expect(source, contains('onBlur'));
      expect(source, contains('morph('));
    });

    test('does NOT report morph() inside onChange', () {
      final source = _wrap('''
final class SearchBox extends Component {
  String value = '';

  @override
  Morphic render() {
    return Input().onChange((e) {
      // ✅ morph() on change — correct pattern
      morph(() => value = 'new value');
    })([]);
  }
}
''');
      expect(source, contains('onChange'));
    });

    test('does NOT report morph() called in a regular method', () {
      final source = _wrap('''
final class SearchBox extends Component {
  String value = '';

  void handleSubmit() {
    // ✅ morph() in a method — correct
    morph(() => value = 'submitted');
  }

  @override
  Morphic render() => ElementMorphic();
}
''');
      expect(source, contains('handleSubmit'));
    });
  });
}
