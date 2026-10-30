// Run CPF Flutter with OHOS dependencies without changing the root Pub files.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, execSync } = require('node:child_process');

const nativeRoot = fs.realpathSync(__dirname);
const repositoryRoot = path.dirname(nativeRoot);
const projectPath = path.join(nativeRoot, '.flutter-workspace');

function copyIfChanged(source, destination) {
  const contents = fs.readFileSync(source);
  if (fs.existsSync(destination) && contents.equals(fs.readFileSync(destination))) return false;
  fs.copyFileSync(source, destination);
  return true;
}

function linkPath(destination, source, directory = true) {
  if (fs.existsSync(destination) || fs.lstatSync(destination, { throwIfNoEntry: false })) {
    if (fs.realpathSync(destination) !== fs.realpathSync(source)) {
      throw new Error(`Expected ${destination} to link to ${source}`);
    }
    return;
  }
  fs.symlinkSync(source, destination,
    directory ? (process.platform === 'win32' ? 'junction' : 'dir') : 'file');
}

function prepareSources() {
  const sourceRoot = path.join(repositoryRoot, 'lib');
  const destinationRoot = path.join(projectPath, 'lib');
  const previous = fs.lstatSync(destinationRoot, { throwIfNoEntry: false });
  // Migrate only the old, verified junction. Never remove a real source directory.
  if (previous?.isSymbolicLink()) {
    if (fs.realpathSync(destinationRoot) !== fs.realpathSync(sourceRoot)) {
      throw new Error(`Unexpected lib link: ${destinationRoot}`);
    }
    fs.unlinkSync(destinationRoot);
  }
  fs.mkdirSync(destinationRoot, { recursive: true });
  const entries = fs.readdirSync(sourceRoot, { withFileTypes: true });
  const currentNames = new Set([...entries.map(entry => entry.name), 'upstream_main.dart', 'ohos_bootstrap']);
  for (const previousName of fs.readdirSync(destinationRoot)) {
    if (currentNames.has(previousName)) continue;
    const destination = path.join(destinationRoot, previousName);
    const expected = path.toNamespacedPath(path.join(sourceRoot, previousName));
    const stat = fs.lstatSync(destination);
    if (!stat.isSymbolicLink() ||
        path.toNamespacedPath(path.resolve(destinationRoot, fs.readlinkSync(destination))) !== expected) {
      throw new Error(`Unexpected file in generated lib directory: ${destination}`);
    }
    // Remove only our obsolete link, never its source or a real directory.
    fs.unlinkSync(destination);
  }
  for (const entry of entries) {
    if (entry.name === 'main.dart') continue;
    if (['upstream_main.dart', 'ohos_bootstrap'].includes(entry.name)) {
      throw new Error(`Reserved OHOS workspace name: lib/${entry.name}`);
    }
    linkPath(path.join(destinationRoot, entry.name), path.join(sourceRoot, entry.name), entry.isDirectory());
  }
  linkPath(path.join(destinationRoot, 'upstream_main.dart'), path.join(sourceRoot, 'main.dart'), false);
  linkPath(path.join(destinationRoot, 'ohos_bootstrap'), path.join(nativeRoot, 'flutter'));
  // Both Flutter CLI and DevEco use their usual lib/main.dart entry point.
  // Only this tiny launcher is generated; all business sources remain linked.
  const launcher = "import 'ohos_bootstrap/main.dart' as bootstrap;\n\nFuture<void> main() => bootstrap.main();\n";
  const mainPath = path.join(destinationRoot, 'main.dart');
  if (fs.lstatSync(mainPath, { throwIfNoEntry: false })?.isSymbolicLink()) {
    throw new Error(`Refusing to overwrite linked main.dart: ${mainPath}`);
  }
  if (!fs.existsSync(mainPath) || fs.readFileSync(mainPath, 'utf8') !== launcher) {
    fs.writeFileSync(mainPath, launcher);
  }
}

function prepareWorkspace() {
  fs.mkdirSync(projectPath, { recursive: true });
  const rootVersion = fs.readFileSync(path.join(repositoryRoot, 'pubspec.yaml'), 'utf8').match(/^version:\s*(\S+)/m)?.[1];
  const ohosVersion = fs.readFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'utf8').match(/^version:\s*(\S+)/m)?.[1];
  if (!rootVersion || rootVersion !== ohosVersion) {
    throw new Error('Synchronize the app version in ohos/pubspec.yaml with the root pubspec.yaml first.');
  }
  prepareSources();
  for (const name of ['assets', 'docs', 'test', 'test_driver']) {
    linkPath(path.join(projectPath, name), path.join(repositoryRoot, name));
  }
  // This is a link to the existing native project, not a second native checkout.
  linkPath(path.join(projectPath, 'ohos'), nativeRoot);
  for (const name of ['l10n.yaml', 'analysis_options.yaml', 'CHANGELOG.md', '.metadata']) {
    const source = path.join(repositoryRoot, name);
    if (fs.existsSync(source)) copyIfChanged(source, path.join(projectPath, name));
  }
  let dependenciesChanged = false;
  for (const name of ['pubspec.yaml', 'pubspec.lock']) {
    dependenciesChanged = copyIfChanged(path.join(nativeRoot, name), path.join(projectPath, name)) ||
      dependenciesChanged;
  }
  return dependenciesChanged;
}

function flutterExecutable() {
  const propertiesPath = path.join(nativeRoot, 'local.properties');
  const properties = fs.existsSync(propertiesPath) ? fs.readFileSync(propertiesPath, 'utf8') : '';
  const configured = properties.match(/^flutter\.sdk\s*=\s*(.+)$/m)?.[1].trim()
    .replace(/\\\\/g, '\\').replace(/\\:/g, ':');
  const sdk = process.env.CPF_FLUTTER_ROOT || configured || process.env.FLUTTER_ROOT;
  if (!sdk || !fs.existsSync(path.join(sdk, 'packages', 'flutter_tools', 'lib', 'src', 'ohos'))) {
    throw new Error('Set CPF_FLUTTER_ROOT or ohos/local.properties flutter.sdk to a CPF Flutter SDK (not upstream Flutter).');
  }
  return path.join(sdk, 'bin', process.platform === 'win32' ? 'flutter.bat' : 'flutter');
}

function prepareNativeProperties() {
  const executable = flutterExecutable();
  const propertiesPath = path.join(nativeRoot, 'local.properties');
  let properties = fs.existsSync(propertiesPath) ? fs.readFileSync(propertiesPath, 'utf8') : '';
  const version = fs.readFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'utf8').match(/^version:\s*(\S+)/m)?.[1];
  if (!version || !/^.+\+\d+$/.test(version)) throw new Error('OHOS version must include a numeric build number.');
  const [versionName, versionCode] = version.split('+');
  const values = {
    'flutter.sdk': path.dirname(path.dirname(executable)).replace(/\\/g, '/'),
    'flutter.versionName': versionName,
    'flutter.versionCode': versionCode,
  };
  for (const [key, value] of Object.entries(values)) {
    const pattern = new RegExp(`^${key.replace(/\./g, '\\.')}\\s*=.*$`, 'm');
    properties = pattern.test(properties)
      ? properties.replace(pattern, () => `${key}=${value}`)
      : `${properties.trimEnd()}\n${key}=${value}\n`;
  }
  if (!fs.existsSync(propertiesPath) || fs.readFileSync(propertiesPath, 'utf8') !== properties) {
    fs.writeFileSync(propertiesPath, properties);
  }
  return executable;
}

function runFlutter(args) {
  const options = {
    cwd: projectPath,
    stdio: 'inherit',
    env: { ...process.env, PUB_HOSTED_URL: process.env.PUB_HOSTED_URL || 'https://pub.flutter-io.cn' },
  };
  const executable = prepareNativeProperties();
  if (process.platform === 'win32') {
    // cmd.exe is required for Flutter's .bat launcher. Reject expansion/quote characters.
    const command = [executable, ...args].map(value => {
      if (/["%!\r\n]/.test(value)) throw new Error('Unsupported character in Flutter command argument');
      return `"${value}"`;
    }).join(' ');
    execSync(command, options);
  } else {
    execFileSync(executable, args, options);
  }
}

module.exports = { prepareWorkspace, projectPath, runFlutter, flutterExecutable, prepareNativeProperties };

if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    if (args.length === 0) throw new Error('Usage: node ohos/flutterw.cjs <Flutter arguments | prepare>');
    if (['create', 'clean'].includes(args[0])) {
      throw new Error('Do not run create/clean through linked sources. Remove only ohos/.flutter-workspace build caches manually.');
    }
    if (args[0] === 'build' && args[1] !== 'hap') {
      throw new Error('Use upstream Flutter in the repository root for non-HAP builds.');
    }
    const changed = prepareWorkspace();
    if (args[0] !== 'prepare') {
      if (['build', 'run', 'drive'].includes(args[0]) &&
          (changed || !fs.existsSync(path.join(projectPath, '.dart_tool', 'package_config.json')))) {
        runFlutter(['pub', 'get', '--no-example', '--enforce-lockfile']);
      }
      // Implicit resolution during a build must never silently change the OHOS lock.
      if (['build', 'run', 'drive'].includes(args[0]) && !args.includes('--no-pub')) {
        args.push('--no-pub');
      }
      runFlutter(args);
      if (args[0] === 'pub' && ['get', 'upgrade', 'downgrade'].includes(args[1])) {
        copyIfChanged(path.join(projectPath, 'pubspec.lock'), path.join(nativeRoot, 'pubspec.lock'));
      }
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = Number.isInteger(error.status) ? error.status : 1;
  }
}
