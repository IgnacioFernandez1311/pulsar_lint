# pulsar_lint

Official lint package for the [Pulsar Web Framework](https://pulsar-web.netlify.app). Enforces architectural best practices through static analysis — so the framework's philosophy is upheld by tooling, not just documentation.

> *Clarity over cleverness. Enforced.*

---

## Why a linter?

Pulsar's core principle — **explicit architecture over convenient shortcuts** — is easy to understand and easy to forget under deadline pressure. `pulsar_lint` makes violations visible the moment they're written, not when they surface as bugs in production.

The rules don't just catch errors. They explain *why* the pattern is wrong and what the correct Pulsar approach looks like. Every error message is a small piece of education.

---

## Rules

### `no_logic_in_render` — ERROR

**`render()` must be a pure description of the UI.**

Data transformations inside `render()` introduce logic where there should be none. They also violate Pulsar's rule against lazy iteration in render, which can cause subtle reconciliation bugs.

```dart
// ❌ no_logic_in_render
@override
Morphic render() {
  return Ul()([
    users.map((u) => UserCard(u)).toList(),  // transformation in render
  ]);
}

// ✅ correct — computation extracted to a getter
List<UserCard> get userCards =>
    users.map((u) => UserCard(u)).toList();

@override
Morphic render() => Ul()([userCards]);
```

**Flagged methods:** `map`, `where`, `fold`, `reduce`, `expand`, `forEach`, `any`, `every`, `firstWhere`, `lastWhere`, `singleWhere`.

Fluent `ElementBuilder` calls (e.g. `Div().classes(...)`) are never flagged — those are UI description, not data transformation.

---

### `no_inline_component_creation` — ERROR

**Components created inline in `render()` lose their identity on every morph.**

Pulsar components are long-lived objects. Their state, their DOM node registration, and the granular diffing model all depend on the instance surviving across re-renders. Creating a component inline means a new instance on every morph — state is lost and diffing breaks.

```dart
// ❌ no_inline_component_creation
@override
Morphic render() {
  return Div()([Counter()]);  // new Counter on every render — identity lost
}

// ✅ correct — stored as a field, created once
final Counter counter = Counter();

@override
Morphic render() => Div()([counter]);
```

---

### `components_must_be_fields` — WARNING

**A Component stored in a local variable is recreated on every method call.**

This complements `no_inline_component_creation`. That rule catches inline creation inside `render()` specifically. This rule catches Component instances declared as local variables anywhere inside a Component's methods — the same identity problem, just one step removed.

```dart
// ❌ components_must_be_fields
final class App extends Component {
  @override
  Morphic render() {
    final header = Header();  // recreated on every render call
    return Div()([header]);
  }
}

// ✅ correct — field declaration
final class App extends Component {
  final Header header = Header();  // created once, lives with App

  @override
  Morphic render() => Div()([header]);
}
```

---

### `no_morph_in_on_input` — WARNING

**`morph()` inside `onInput` re-renders on every keystroke.**

`onInput` fires continuously as the user types. Calling `morph()` there triggers a full DOM diff on every character — unnecessary rendering pressure that can cause the input to lose focus or the cursor to jump.

The correct pattern is to update state in memory on input and only call `morph()` on events that signal the user has finished interacting.

```dart
// ❌ no_morph_in_on_input
Input().onInput((e) {
  morph(() => value = (e.target as HTMLInputElement).value);
})

// ✅ correct — update in memory, morph on blur
Input()
  .onInput((e) {
    value = (e.target as HTMLInputElement).value;  // no re-render
  })
  .onBlur((_) => morph(() {}))  // re-render when the user leaves the field
```

---

## Contributing

Contributions are welcome if they align with Pulsar's philosophy. Before writing code, read the [Pulsar ROADMAP](https://github.com/IgnacioFernandez1311/pulsar_web/blob/main/ROADMAP.md) to understand what the framework is and — equally important — what it deliberately is not.

### Adding a new rule

Each rule lives in `lib/src/rules/` as its own file. The steps are:

**1. Create the rule class**

```dart
// lib/src/rules/your_rule_name.dart

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

class YourRuleName extends DartLintRule {
  YourRuleName() : super(code: _code);

  static const _code = LintCode(
    name: 'your_rule_name',
    problemMessage: "Description of what's wrong.",
    correctionMessage: "Description of the correct pattern.",
    errorSeverity: ErrorSeverity.WARNING, // or ERROR
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Use helpers from pulsar_ast_utils.dart to check context:
      // - extendsPulsarComponent(classDecl)
      // - isInsidePulsarMethod(node, 'render')
      // - typeIsElementBuilder(type)
      // - enclosingClass(node), enclosingMethod(node)

      if (!isInsidePulsarMethod(node, 'render')) return;

      reporter.atNode(node, _code);
    });
  }
}
```

**2. Register it in `PulsarPlugin`**

```dart
// lib/src/pulsar_plugin.dart

@override
List<LintRule> getLintRules(CustomLintConfigs configs) => [
  NoLogicInRender(),
  NoInlineComponentCreation(),
  ComponentsMustBeFields(),
  NoMorphInOnInput(),
  YourRuleName(), // ← add here
];
```

**3. Write tests**

Tests go in `test/rules/`. Each test file covers one rule with both positive cases (code that should be flagged) and negative cases (correct code that should not be flagged).

### AST utilities

`lib/src/pulsar_ast_utils.dart` contains helpers shared across all rules. Use these rather than reimplementing type checks in each rule:

| Helper | Purpose |
|---|---|
| `extendsPulsarComponent(classDecl)` | Returns true if a `ClassDeclaration` extends `Component` from pulsar_web |
| `typeExtendsPulsarComponent(type)` | Same check from a `DartType` |
| `typeIsElementBuilder(type)` | Returns true if a type is `ElementBuilder` or a subclass |
| `enclosingClass(node)` | Walks up the AST to find the nearest `ClassDeclaration` |
| `enclosingMethod(node)` | Walks up the AST to find the nearest `MethodDeclaration` |
| `isInsidePulsarMethod(node, name)` | Returns true if a node is directly inside a named method of a Pulsar Component |
| `isElementBuilderEventCall(invocation, name)` | Returns true if a method call is an event registration on an `ElementBuilder` |

### Contribution guidelines

- **Open an issue first** — discuss the rule before implementing it. A rule that can't be explained in two sentences probably shouldn't exist.
- **Rules must have a clear architectural reason** — "this is a code smell" is not enough. The violation must map to a specific Pulsar principle.
- **Both error severity levels are valid** — use `ERROR` for patterns that break the framework (identity, purity), `WARNING` for patterns that undermine the philosophy without necessarily breaking things.
- **The correction message matters as much as the problem message** — it should show the correct Pulsar pattern, not just say "don't do this".

### What we won't accept

- Rules that enforce style preferences with no architectural grounding
- Rules that fire on code outside of Pulsar Component classes
- Rules that require configuration to be useful — a rule that needs tuning to make sense is a rule that doesn't make sense

---

## Compatibility

| pulsar_lint | pulsar_web | analyzer | custom_lint |
|---|---|---|---|
| 0.1.x | 1.x | 8.4.0 | 0.8.1 |

---

## Links

- [Pulsar Web Framework](https://pulsar-web.netlify.app)
- [Documentation](https://pulsar-web.netlify.app/docs)
- [GitHub](https://github.com/IgnacioFernandez1311/pulsar_web)
- [Issues](https://github.com/IgnacioFernandez1311/pulsar_web/issues)
- [Discussions](https://github.com/IgnacioFernandez1311/pulsar_web/discussions)

---

*Built with clarity. Maintained with discipline. Evolved with intention.*
