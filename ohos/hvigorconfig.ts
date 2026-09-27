import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const flutterProjectPath = path.dirname(__dirname);
const pluginsFile = path.join(flutterProjectPath, '.flutter-plugins-dependencies');
const hvigorPlugin = path.join(__dirname, 'node_modules', 'flutter-hvigor-plugin');
const dependencies = ['pubspec.yaml', 'pubspec.lock'];

if (!fs.existsSync(hvigorPlugin) ||
    !fs.existsSync(pluginsFile) ||
    dependencies.some(file =>
      fs.statSync(path.join(flutterProjectPath, file)).mtimeMs > fs.statSync(pluginsFile).mtimeMs)) {
  execSync('flutter pub get --no-example --enforce-lockfile', {
    cwd: flutterProjectPath,
    stdio: 'inherit',
    env: { ...process.env, PUB_HOSTED_URL: 'https://pub.flutter-io.cn' },
  });
}

// Pub get installs this local package before Hvigor loads its configuration.
const { injectNativeModules } = require('flutter-hvigor-plugin');
injectNativeModules(__dirname, flutterProjectPath);
