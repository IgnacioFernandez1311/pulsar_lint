// lib/pulsar_linter.dart

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_plugin.dart';

/// Entry point required by custom_lint.
///
/// The host process calls [createPlugin] once to obtain the plugin instance.
/// All lint rules are registered inside [PulsarPlugin].
PluginBase createPlugin() => PulsarPlugin();
