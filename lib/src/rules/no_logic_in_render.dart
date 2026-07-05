// lib/src/rules/no_logic_in_render.dart

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

/// Flags data transformation methods used directly inside [render()].
///
/// ## Why
///
/// [render()] must be a pure description of the UI — a mapping from state
/// to structure. Any computation, especially list transformations, is domain
/// logic that belongs in a getter or a domain object, not in the render tree.
///
/// Using [.map()], [.where()], or similar methods directly in [render()]
/// also violates Pulsar's rule against lazy iteration inside render, which
/// can cause subtle identity and reconciliation bugs.
///
/// ## Bad
///
/// ```dart
/// @override
/// Morphic render() {
///   return Ul()([
///     users.map((u) => UserCard(u)).toList(), // ❌
///   ]);
/// }
/// ```
///
/// ## Good
///
/// ```dart
/// List<Morphic> get userCards =>
///     users.map((u) => UserCard(u)).toList();
///
/// @override
/// Morphic render() => Ul()([userCards]); // ✅
/// ```
class NoLogicInRender extends DartLintRule {
  NoLogicInRender() : super(code: _code);

  static const _code = LintCode(
    name: 'no_logic_in_render',
    problemMessage:
        "Avoid '{0}()' inside render(). "
        "Move this transformation to a getter.",
    correctionMessage:
        "Extract the transformation to a getter:\n"
        "  List<Morphic> get items => source.{0}(...).toList();\n"
        "Then reference the getter in render().",
    errorSeverity: .ERROR,
  );

  static const _forbiddenMethods = {
    'map',
    'where',
    'fold',
    'reduce',
    'expand',
    'forEach',
    'any',
    'every',
    'firstWhere',
    'lastWhere',
    'singleWhere',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final name = node.methodName.name;
      if (!_forbiddenMethods.contains(name)) return;

      // Only fire inside render() of a Pulsar Component
      if (!isInsidePulsarMethod(node, 'render')) return;

      // Never flag fluent ElementBuilder calls — those are UI description,
      // not data transformation. e.g. Div().classes(...) is fine.
      final target = node.realTarget;
      if (target != null) {
        final type = target.staticType;
        if (type != null && typeIsElementBuilder(type)) return;
      }

      reporter.atNode(node, _code, arguments: [name]);
    });
  }
}
