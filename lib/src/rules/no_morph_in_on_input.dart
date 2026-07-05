// lib/src/rules/no_morph_in_on_input.dart

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

/// Flags [morph()] calls inside [onInput] event handler callbacks.
///
/// ## Why
///
/// [onInput] fires on every keystroke. Calling [morph()] — which triggers a
/// DOM diff and re-render — on every keystroke causes unnecessary rendering
/// pressure and can cause the cursor to jump or the input to lose focus.
///
/// The correct pattern is to update state in memory on input and only call
/// [morph()] on significant events like [onBlur] or [onChange].
///
/// ## Bad
///
/// ```dart
/// Input().onInput((e) {
///   morph(() => value = (e.target as HTMLInputElement).value); // ❌
/// })
/// ```
///
/// ## Good
///
/// ```dart
/// // Update in memory — no re-render on every keystroke
/// Input().onInput((e) {
///   value = (e.target as HTMLInputElement).value; // ✅
/// })
/// // Re-render only when the user finishes
/// .onBlur((_) => morph(() {}))
/// ```
class NoMorphInOnInput extends DartLintRule {
  NoMorphInOnInput() : super(code: _code);

  static const _code = LintCode(
    name: 'no_morph_in_on_input',
    problemMessage:
        "Avoid calling morph() inside an onInput handler. "
        "onInput fires on every keystroke, causing unnecessary re-renders.",
    correctionMessage:
        "Update state in memory inside onInput without calling morph().\n"
        "Call morph() inside onBlur or onChange instead — those fire only "
        "when the user has finished interacting with the field.",
    errorSeverity: .WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'morph') return;
      if (_isInsideOnInputCallback(node)) {
        reporter.atNode(node, _code);
      }
    });
  }

  /// Returns true if [node] is inside a function expression that is passed
  /// as the argument to an [onInput] call on an [ElementBuilder].
  bool _isInsideOnInputCallback(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      if (current is FunctionExpression) {
        final argumentList = current.parent;
        if (argumentList is! ArgumentList) {
          current = current.parent;
          continue;
        }

        final methodCall = argumentList.parent;
        if (methodCall is! MethodInvocation) {
          current = current.parent;
          continue;
        }

        if (isElementBuilderEventCall(methodCall, 'onInput')) {
          return true;
        }
      }

      // Stop traversal if we leave the enclosing Component method scope
      if (current is MethodDeclaration) {
        final classDecl = enclosingClass(current);
        if (classDecl == null || !extendsPulsarComponent(classDecl)) {
          return false;
        }
      }

      current = current.parent;
    }

    return false;
  }
}
