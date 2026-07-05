/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:pulsar_lint/src/pulsar_plugin.dart';

export 'src/pulsar_lint_base.dart';

PluginBase createPlugin() => PulsarPlugin();
