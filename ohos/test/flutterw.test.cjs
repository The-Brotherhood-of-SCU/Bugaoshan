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
    'ohos/pubspec.yaml': 'name: bugaoshan\nversion: 2.5.3+20503\n',
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

test('version drift fails instead of changing either dependency manifest', (t) => {
  const { root, nativeRoot, wrapper } = fixture(t);
  fs.writeFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'version: 1.0.0+1\n');
  assert.throws(() => wrapper.prepareWorkspace(), /Synchronize the app version/);
  assert.equal(fs.readFileSync(path.join(root, 'pubspec.lock'), 'utf8'), 'upstream-lock');
  assert.equal(fs.readFileSync(path.join(nativeRoot, 'pubspec.yaml'), 'utf8'), 'version: 1.0.0+1\n');
});

test('upstream file removal clears only its obsolete workspace link', (t) => {
  const { root, wrapper } = fixture(t);
  wrapper.prepareWorkspace();
  fs.unlinkSync(path.join(root, 'lib/app.dart'));
  wrapper.prepareWorkspace();
  assert.equal(fs.lstatSync(path.join(wrapper.projectPath, 'lib/app.dart'), { throwIfNoEntry: false }), undefined);
  assert.equal(fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8'), 'upstream-main');
});
