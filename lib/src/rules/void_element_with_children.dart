// lib/src/rules/void_element_with_children.dart

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

/// Flags void elements that receive children in their [call()] invocation.
///
/// ## Why
///
/// Void elements (`Input`, `Img`, `Br`, `Hr`, etc.) cannot have children by
/// definition — both in HTML and in Pulsar. The [ElementBuilder.call()] method
/// will throw an [ArgumentError] at runtime if children are passed to a void
/// element. This rule catches that mistake at analysis time.
///
/// ## Bad
///
/// ```dart
/// Input()(['some text'])  // ❌ void element with children
/// Img()([Span()(['alt'])])  // ❌ void element with children
/// Br()([''])  // ❌ void element with children
/// ```
///
/// ## Good
///
/// ```dart
/// Input()()    // ✅ void element — no children
/// Img().src('/logo.png')()  // ✅ void element — no children
/// Br()()       // ✅ void element — no children
/// ```
class VoidElementWithChildren extends DartLintRule {
  VoidElementWithChildren() : super(code: _code);

  static const _code = LintCode(
    name: 'void_element_with_children',
    problemMessage:
        "'{0}' is a void element and cannot have children. "
        "Use {0}()() without arguments.",
    correctionMessage:
        "Remove the children list from the call() invocation:\n"
        "  {0}()()  // ✅ correct\n"
        "Void elements produce no DOM children by definition.",
    errorSeverity: .ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpressionInvocation((node) {
      // We are looking for the call() invocation pattern: Expr()(children)
      // In the AST this is a FunctionExpressionInvocation where the function
      // is itself an InstanceCreationExpression or another invocation.

      // Check that there is at least one argument (the children list)
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // The first argument must be a list literal with content — call()
      // with an empty list [] is technically allowed (it's a no-op),
      // but semantically wrong for void elements.
      final firstArg = args.first;
      if (firstArg is! ListLiteral) return;

      // Get the static type of the target expression (the builder instance)
      final target = node.function;
      final targetType = target.staticType;
      if (targetType == null) return;

      // Only fire for ElementBuilder subclasses from pulsar_web
      if (!typeIsElementBuilder(targetType)) return;

      // Check if the builder type is a void element by walking the
      // constructor call that created it. Void elements pass isVoid: true
      // to their super constructor — we detect this via the type name
      // matched against the known void element set.
      if (!_isVoidElementType(targetType)) return;

      final typeName = _elementTypeName(targetType);
      reporter.atNode(node, _code, arguments: [typeName]);
    });
  }

  /// Returns true if [type] is a known Pulsar void element.
  ///
  /// Void elements are those whose constructor passes `isVoid: true` to
  /// [ElementBuilder]. Rather than trying to read constructor arguments
  /// statically (which is brittle), we match against the canonical set of
  /// void element class names defined in pulsar_web.
  bool _isVoidElementType(DartType type) {
    if (type is! InterfaceType) return false;
    final name = type.element.name;
    return _voidElements.contains(name);
  }

  String _elementTypeName(DartType type) {
    if (type is InterfaceType) return type.element.name!;
    return type.toString();
  }

  /// Canonical set of void element class names from pulsar_web.
  /// These correspond to all ElementBuilder subclasses instantiated
  /// with isVoid: true in void_elements.dart.
  static const _voidElements = {
    'Input',
    'Img',
    'Br',
    'Hr',
    'Wbr',
    'Meta',
    'Link',
    'Base',
    'Source',
    'Track',
    'Col',
    'Param',
    'Area',
    'Path',
    'Polyline',
  };
}
