// lib/src/rules/element_builder_missing_call.dart

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

/// Flags [ElementBuilder] instances used as values without invoking [call()].
///
/// ## Why
///
/// Every [ElementBuilder] in Pulsar must be finalized with [call()] to produce
/// a [Morphic] node. Without [call()], the builder instance itself is passed
/// instead of a [Morphic] — the tree will fail to resolve at runtime.
///
/// This includes both content elements, which require a children list:
///   `Div()([...])`
/// And void elements, which require an empty call:
///   `Input()()`
///
/// ## Bad
///
/// ```dart
/// @override
/// Morphic render() {
///   return Div()([
///     Span(),        // ❌ missing call — builder, not Morphic
///     Input(),       // ❌ missing call — builder, not Morphic
///   ]);
/// }
/// ```
///
/// ## Good
///
/// ```dart
/// @override
/// Morphic render() {
///   return Div()([
///     Span()(['Hello']),  // ✅ content element with children
///     Input()(),          // ✅ void element finalized
///   ]);
/// }
/// ```
class ElementBuilderMissingCall extends DartLintRule {
  ElementBuilderMissingCall() : super(code: _code);

  static const _code = LintCode(
    name: 'element_builder_missing_call',
    problemMessage:
        "'{0}' is an ElementBuilder but call() was not invoked. "
        "This produces a builder instance instead of a Morphic node.",
    correctionMessage:
        "Invoke call() to finalize the element:\n"
        "  For content elements: {0}()([children])\n"
        "  For void elements:    {0}()()\n"
        "\n"
        "Without call(), the builder is never converted to a Morphic node "
        "and the tree will fail to resolve at runtime.",
    errorSeverity: .ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      // We are looking for ElementBuilder instances that are NOT immediately
      // followed by a call() or a fluent method chain ending in call().
      //
      // The key insight: if the parent of this InstanceCreationExpression is
      // a MethodInvocation (fluent chain) or a FunctionExpressionInvocation
      // (call()), it's fine. If the parent is anything else — an argument
      // list, a return statement, a variable declaration — call() is missing.

      final type = node.staticType;
      if (type == null) return;
      if (!typeIsElementBuilder(type)) return;

      // Walk up the parent chain. If we find a FunctionExpressionInvocation
      // before hitting a "consumer" node, call() is present.
      if (_hasCallInvocation(node)) return;

      final typeName = _elementTypeName(type);
      reporter.atNode(node, _code, arguments: [typeName]);
    });
  }

  /// Returns true if [node] is part of an expression chain that ends
  /// with a [call()] invocation — either directly or through fluent methods.
  ///
  /// Patterns considered as having call():
  ///   Div()([])                  → direct FunctionExpressionInvocation
  ///   Div().classes('x')([])     → InstanceCreation → MethodInvocation → FEI
  ///   Input().type(text)()       → InstanceCreation → MethodInvocation → FEI
  bool _hasCallInvocation(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      // Found a FunctionExpressionInvocation — this is the call() operator
      if (current is FunctionExpressionInvocation) return true;

      // Still in a fluent method chain on the builder — keep walking up
      if (current is MethodInvocation && current.target != null) {
        current = current.parent;
        continue;
      }

      // Hit a consumer node — the chain ended without call()
      break;
    }

    return false;
  }

  String _elementTypeName(DartType type) {
    if (type is InterfaceType) return type.element.name!;
    return type.toString();
  }
}
