// lib/src/pulsar_plugin.dart

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/rules/no_logic_in_render.dart';
import 'package:pulsar_lint/src/rules/no_inline_component_creation.dart';
import 'package:pulsar_lint/src/rules/components_must_be_fields.dart';
import 'package:pulsar_lint/src/rules/no_morph_in_on_input.dart';

/// The Pulsar lint plugin.
///
/// Registers all rules with the custom_lint host. Rules are applied to every
/// Dart file in the project that uses pulsar_web.
///
/// To enable, add to your project's pubspec.yaml:
/// ```yaml
/// dev_dependencies:
///   custom_lint: any
///   pulsar_linter: any
/// ```
///
/// And to analysis_options.yaml:
/// ```yaml
/// analyzer:
///   plugins:
///     - custom_lint
/// ```
class PulsarPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    NoLogicInRender(),
    NoInlineComponentCreation(),
    ComponentsMustBeFields(),
    NoMorphInOnInput(),
  ];
}
