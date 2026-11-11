import fs from 'fs';
import path from 'path';
const { prepareWorkspace, projectPath: flutterProjectPath, runFlutter, prepareNativeProperties } = require('./flutterw.cjs');

const nativeProjectPath = fs.realpathSync(__dirname);
const dependenciesChanged = prepareWorkspace();
prepareNativeProperties();
const pluginsFile = path.join(flutterProjectPath, '.flutter-plugins-dependencies');
const hvigorPlugin = path.join(nativeProjectPath, 'node_modules', 'flutter-hvigor-plugin');
const dependencies = ['pubspec.yaml', 'pubspec.lock'];

if (dependenciesChanged || !fs.existsSync(hvigorPlugin) ||
    !fs.existsSync(pluginsFile) ||
    !fs.existsSync(path.join(flutterProjectPath, '.dart_tool', 'package_config.json')) ||
    dependencies.some(file =>
      fs.statSync(path.join(flutterProjectPath, file)).mtimeMs > fs.statSync(pluginsFile).mtimeMs)) {
  runFlutter(['pub', 'get', '--no-example', '--enforce-lockfile']);
}

const { injectNativeModules } = require('flutter-hvigor-plugin');
injectNativeModules(nativeProjectPath, flutterProjectPath);
