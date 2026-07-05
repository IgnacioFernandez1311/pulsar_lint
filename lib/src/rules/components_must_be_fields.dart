// lib/src/rules/components_must_be_fields.dart

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_ast_utils.dart';

/// Warns when a Pulsar [Component] is stored as a local variable inside
/// a method instead of as a field of the enclosing Component class.
///
/// ## Why
///
/// A local variable is recreated on every method call. A field lives for the
/// entire lifetime of the component. Pulsar's identity model depends on
/// component instances being stable across morphs — local variables break that.
///
/// This rule complements [no_inline_component_creation]: that rule catches
/// inline creation specifically inside [render()], while this rule catches
/// local variable declarations of Component types in any method.
///
/// ## Bad
///
/// ```dart
/// final class App extends Component {
///   @override
///   Morphic render() {
///     final header = Header(); // ❌ recreated on every render
///     return Div()([header]);
///   }
/// }
/// ```
///
/// ## Good
///
/// ```dart
/// final class App extends Component {
///   final Header header = Header(); // ✅ created once, lives with App
///
///   @override
///   Morphic render() => Div()([header]);
/// }
/// ```
class ComponentsMustBeFields extends DartLintRule {
  ComponentsMustBeFields() : super(code: _code);

  static const _code = LintCode(
    name: 'components_must_be_fields',
    problemMessage:
        "'{0}' is a Pulsar Component stored as a local variable. "
        "Its identity is lost on every method call.",
    correctionMessage:
        "Declare '{0}' as a field of the enclosing Component:\n"
        "  final {1} {0} = {1}();\n"
        "\n"
        "Local variables are re-created on every call, "
        "breaking Pulsar's identity model.",
    errorSeverity: .WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclarationStatement((node) {
      // Only fire inside a method of a Pulsar Component class
      final method = enclosingMethod(node);
      if (method == null) return;

      final classDecl = enclosingClass(method);
      if (classDecl == null) return;
      if (!extendsPulsarComponent(classDecl)) return;

      for (final variable in node.variables.variables) {
        // analyzer 8.x: use declaredFragment to get the element
        final element = variable.declaredFragment?.element;
        if (element == null) continue;

        final type = element.type;
        if (!typeExtendsPulsarComponent(type)) continue;

        final varName = variable.name.lexeme;
        final typeName = _typeName(type);

        reporter.atNode(variable, _code, arguments: [varName, typeName]);
      }
    });
  }

  String _typeName(dynamic type) {
    if (type is dynamic && type.element != null) {
      return (type.element as dynamic).name as String? ?? type.toString();
    }
    return type.toString();
  }
}
