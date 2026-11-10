const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'bugaoshan-flutterw-'));
  // Only this test-created directory is removed. fs.rm does not follow links.
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const nativeRoot = path.join(root, 'ohos');
  for (const directory of ['lib', 'lib/services', 'assets', 'docs', 'test', 'test_driver', 'ohos/flutter']) {
    fs.mkdirSync(path.join(root, directory), { recursive: true });
  }
  for (const [file, contents] of Object.entries({
    'lib/main.dart': 'upstream-main',
    'lib/app.dart': 'shared-app',
    'lib/services/example.dart': 'shared-service',
    'pubspec.yaml': 'name: bugaoshan\nversion: 2.5.3+20503\n',
    'pubspec.lock': 'upstream-lock',
    'ohos/pubspec.yaml': 'name: bugaoshan\ndependencies:\n  ohos_plugin: any\n',
    'ohos/pubspec.lock': 'ohos-lock',
    'ohos/flutter/main.dart': 'ohos-main',
  })) fs.writeFileSync(path.join(root, file), contents);
  const script = path.join(nativeRoot, 'flutterw.cjs');
  fs.copyFileSync(path.join(__dirname, '..', 'flutterw.cjs'), script);
  const wrapper = require(script);
  t.after(() => delete require.cache[require.resolve(script)]);
  return { root, nativeRoot, wrapper };
}

test('workspace owns its manifest and lock, and links the single native project', (t) => {
  const { root, nativeRoot, wrapper } = fixture(t);
  assert.equal(wrapper.prepareWorkspace(), true);
  assert.equal(wrapper.prepareWorkspace(), false);
  assert.equal(fs.readFileSync(path.join(wrapper.projectPath, 'pubspec.lock'), 'utf8'), 'ohos-lock');
  assert.equal(fs.realpathSync(path.join(wrapper.projectPath, 'ohos')), fs.realpathSync(nativeRoot));
  fs.writeFileSync(path.join(wrapper.projectPath, 'pubspec.lock'), 'resolved-lock');
  assert.equal(fs.readFileSync(path.join(root, 'pubspec.lock'), 'utf8'), 'upstream-lock');
  assert.equal(fs.readFileSync(path.join(nativeRoot, 'pubspec.lock'), 'utf8'), 'ohos-lock');
});

test('launcher injects OHOS while business sources remain linked and editable', (t) => {
  const { root, wrapper } = fixture(t);
  wrapper.prepareWorkspace();
  const lib = path.join(wrapper.projectPath, 'lib');
  assert.match(fs.readFileSync(path.join(lib, 'main.dart'), 'utf8'), /ohos_bootstrap\/main.dart/);
  assert.equal(fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8'), 'upstream-main');
  assert.equal(fs.realpathSync(path.join(lib, 'upstream_main.dart')), fs.realpathSync(path.join(root, 'lib/main.dart')));
  fs.writeFileSync(path.join(root, 'lib/app.dart'), 'updated-app');
  assert.equal(fs.readFileSync(path.join(lib, 'app.dart'), 'utf8'), 'updated-app');
});

test('old lib junction is replaced without modifying upstream sources', (t) => {
  const { root, wrapper } = fixture(t);
  fs.mkdirSync(wrapper.projectPath);
  fs.symlinkSync(path.join(root, 'lib'), path.join(wrapper.projectPath, 'lib'), process.platform === 'win32' ? 'junction' : 'dir');
  wrapper.prepareWorkspace();
  assert.equal(fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8'), 'upstream-main');
  assert.equal(fs.readFileSync(path.join(root, 'lib/app.dart'), 'utf8'), 'shared-app');
});

test('root-only version bumps update Flutter and native metadata without changing OHOS dependencies', (t) => {
  const { root, nativeRoot, wrapper } = fixture(t);
  const sdk = path.join(root, 'cpf sdk');
  fs.mkdirSync(path.join(sdk, 'packages', 'flutter_tools', 'lib', 'src', 'ohos'), { recursive: true });
  const previousSdk = process.env.CPF_FLUTTER_ROOT;
  process.env.CPF_FLUTTER_ROOT = sdk;
  t.after(() => {
    if (previousSdk === undefined) delete process.env.CPF_FLUTTER_ROOT;
    else process.env.CPF_FLUTTER_ROOT = previousSdk;
  });
  const nativeManifest = fs.readFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'utf8');
  const propertiesPath = path.join(nativeRoot, 'local.properties');
  fs.writeFileSync(propertiesPath, 'custom.setting=preserved\nflutter.versionName=1.0.0\nflutter.versionCode=1\n');

  wrapper.prepareWorkspace();
  wrapper.prepareNativeProperties();
  const generatedPath = path.join(wrapper.projectPath, 'pubspec.yaml');
  assert.equal(fs.readFileSync(generatedPath, 'utf8'), `version: 2.5.3+20503\n${nativeManifest}`);
  assert.match(fs.readFileSync(propertiesPath, 'utf8'), /^flutter.versionName=2\.5\.3$/m);
  assert.match(fs.readFileSync(propertiesPath, 'utf8'), /^flutter.versionCode=20503$/m);

  const nextRootManifest = 'name: bugaoshan\nversion: "2.6.0-rc.1+20600" # release version\n';
  fs.writeFileSync(path.join(root, 'pubspec.yaml'), nextRootManifest);
  assert.equal(wrapper.prepareWorkspace(), true);
  wrapper.prepareNativeProperties();
  assert.equal(fs.readFileSync(generatedPath, 'utf8'), `version: 2.6.0-rc.1+20600\n${nativeManifest}`);
  const properties = fs.readFileSync(propertiesPath, 'utf8');
  assert.match(properties, /^flutter.versionName=2\.6\.0-rc\.1$/m);
  assert.match(properties, /^flutter.versionCode=20600$/m);
  assert.match(properties, /^custom.setting=preserved$/m);
  assert.equal(fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8'), nextRootManifest);
  assert.equal(fs.readFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'utf8'), nativeManifest);
  assert.equal(fs.readFileSync(path.join(root, 'pubspec.lock'), 'utf8'), 'upstream-lock');
  assert.equal(fs.readFileSync(path.join(nativeRoot, 'pubspec.lock'), 'utf8'), 'ohos-lock');
  assert.equal(fs.readFileSync(path.join(wrapper.projectPath, 'pubspec.lock'), 'utf8'), 'ohos-lock');

  const timestamp = new Date('2020-01-01T00:00:00Z');
  for (const file of [generatedPath, propertiesPath]) fs.utimesSync(file, timestamp, timestamp);
  assert.equal(wrapper.prepareWorkspace(), false);
  wrapper.prepareNativeProperties();
  for (const file of [generatedPath, propertiesPath]) assert.equal(fs.statSync(file).mtimeMs, timestamp.getTime());
});

test('a legacy OHOS version cannot override the root version', (t) => {
  const { nativeRoot, wrapper } = fixture(t);
  const nativeManifest = 'name: bugaoshan\r\nversion: 1.0.0+1\r\ndependencies:\r\n  ohos_plugin: any\r\n';
  fs.writeFileSync(path.join(nativeRoot, 'pubspec.yaml'), nativeManifest);
  wrapper.prepareWorkspace();
  const generated = fs.readFileSync(path.join(wrapper.projectPath, 'pubspec.yaml'), 'utf8');
  assert.deepEqual(generated.match(/^version:.*$/gm), ['version: 2.5.3+20503']);
  assert.ok(generated.includes('dependencies:\r\n  ohos_plugin: any\r\n'));
  assert.equal(fs.readFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'utf8'), nativeManifest);
});

test('missing or malformed root versions fail before changing generated metadata', (t) => {
  const { root, wrapper } = fixture(t);
  wrapper.prepareWorkspace();
  const generatedPath = path.join(wrapper.projectPath, 'pubspec.yaml');
  const original = fs.readFileSync(generatedPath, 'utf8');
  for (const versionLine of ['', 'version:', 'version: 2.6.0', 'version: 2.6.0+abc', 'version: invalid+1']) {
    fs.writeFileSync(path.join(root, 'pubspec.yaml'), `name: bugaoshan\n${versionLine}\ndependencies: {}\n`);
    assert.throws(() => wrapper.prepareWorkspace(), /Root pubspec.yaml version/);
    assert.throws(() => wrapper.prepareNativeProperties(), /Root pubspec.yaml version/);
    assert.equal(fs.readFileSync(generatedPath, 'utf8'), original);
  }
});

test('upstream file removal clears only its obsolete workspace link', (t) => {
  const { root, wrapper } = fixture(t);
  wrapper.prepareWorkspace();
  fs.unlinkSync(path.join(root, 'lib/app.dart'));
  wrapper.prepareWorkspace();
  assert.equal(fs.lstatSync(path.join(wrapper.projectPath, 'lib/app.dart'), { throwIfNoEntry: false }), undefined);
  assert.equal(fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8'), 'upstream-main');
});
