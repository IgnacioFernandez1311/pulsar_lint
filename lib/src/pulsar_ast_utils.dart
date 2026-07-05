// lib/src/pulsar_ast_utils.dart

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Component detection
// ─────────────────────────────────────────────────────────────────────────────

/// Returns true if [classDecl] directly or transitively extends
/// the Pulsar [Component] base class from pulsar_web.
bool extendsPulsarComponent(ClassDeclaration classDecl) {
  // analyzer 8.x: use declaredFragment to get the element
  final element = classDecl.declaredFragment?.element;
  if (element == null) return false;
  return _interfaceExtendsPulsarComponent(element.thisType);
}

bool _interfaceExtendsPulsarComponent(DartType type) {
  if (type is! InterfaceType) return false;

  final element = type.element;

  // Direct match: class named 'Component' from pulsar_web
  if (element.name == 'Component' &&
      element.library.identifier.contains('pulsar_web')) {
    return true;
  }

  // Walk the supertype chain
  final supertype = element.supertype;
  if (supertype == null) return false;
  return _interfaceExtendsPulsarComponent(supertype);
}

/// Returns true if [type] extends or is [Component] from pulsar_web.
/// Used when we already have a [DartType] (e.g. from a variable declaration).
bool typeExtendsPulsarComponent(DartType type) {
  return _interfaceExtendsPulsarComponent(type);
}

/// Returns true if [type] extends or is [ElementBuilder] from pulsar_web.
bool typeIsElementBuilder(DartType type) {
  return _interfaceIsElementBuilder(type);
}

bool _interfaceIsElementBuilder(DartType type) {
  if (type is! InterfaceType) return false;
  final element = type.element;

  if (element.name == 'ElementBuilder' &&
      element.library.identifier.contains('pulsar_web')) {
    return true;
  }

  final supertype = element.supertype;
  if (supertype == null) return false;
  return _interfaceIsElementBuilder(supertype);
}

// ─────────────────────────────────────────────────────────────────────────────
// AST traversal helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the nearest enclosing [ClassDeclaration] of [node], or null.
ClassDeclaration? enclosingClass(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is ClassDeclaration) return current;
    current = current.parent;
  }
  return null;
}

/// Returns the nearest enclosing [MethodDeclaration] of [node], or null.
MethodDeclaration? enclosingMethod(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current;
    current = current.parent;
  }
  return null;
}

/// Returns true if [node] is directly inside the body of a method named
/// [methodName] that belongs to a Pulsar Component class.
///
/// "Directly inside" means the nearest enclosing [MethodDeclaration] is
/// [methodName] — not a nested closure or function expression within it.
bool isInsidePulsarMethod(AstNode node, String methodName) {
  final method = enclosingMethod(node);
  if (method == null) return false;
  if (method.name.lexeme != methodName) return false;

  final classDecl = enclosingClass(method);
  if (classDecl == null) return false;

  return extendsPulsarComponent(classDecl);
}

/// Returns true if [invocation] is a call to [eventMethodName] on an
/// [ElementBuilder] — i.e. an event registration like .onInput() or .onBlur().
bool isElementBuilderEventCall(
  MethodInvocation invocation,
  String eventMethodName,
) {
  if (invocation.methodName.name != eventMethodName) return false;

  final target = invocation.realTarget;
  if (target == null) return false;

  final type = target.staticType;
  if (type == null) return false;

  return typeIsElementBuilder(type);
}
