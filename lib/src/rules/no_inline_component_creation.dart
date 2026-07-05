// lib/src/rules/no_inline_component_creation.dart

import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

/// Flags Pulsar [Component] instances created inline inside [render()].
///
/// ## Why
///
/// Components in Pulsar are long-lived objects with identity. Creating them
/// inline in [render()] recreates the instance on every morph — the component
/// loses all internal state and the granular diffing model breaks down because
/// [resolveNode] sees it as a brand new component every time.
///
/// ## Bad
///
/// ```dart
/// @override
/// Morphic render() {
///   return Div()([Counter()]); // ❌ new Counter on every render
/// }
/// ```
///
/// ## Good
///
/// ```dart
/// final Counter counter = Counter(); // ✅ identity preserved
///
/// @override
/// Morphic render() => Div()([counter]);
/// ```
class NoInlineComponentCreation extends DartLintRule {
  NoInlineComponentCreation() : super(code: _code);

  static const _code = LintCode(
    name: 'no_inline_component_creation',
    problemMessage:
        "'{0}' is created inline inside render(). "
        "Component identity is destroyed on every morph.",
    correctionMessage:
        "Store the component as a field and reference it in render():\n"
        "  final {0} myComponent = {0}();\n"
        "\n"
        "  @override\n"
        "  Morphic render() => Div()([myComponent]);",
    errorSeverity: .ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (!isInsidePulsarMethod(node, 'render')) return;

      final type = node.staticType;
      if (type == null) return;
      if (!_typeExtendsPulsarComponent(type)) return;

      final typeName = node.constructorName.type.name2.lexeme;
      reporter.atNode(node, _code, arguments: [typeName]);
    });
  }

  bool _typeExtendsPulsarComponent(DartType type) {
    return typeExtendsPulsarComponent(type);
  }
}
