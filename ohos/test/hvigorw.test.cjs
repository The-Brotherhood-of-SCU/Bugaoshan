const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const { findHvigor } = require('../hvigorw.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'bugaoshan-hvigor-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const nativeRoot = path.join(root, 'native project');
  const hvigorHome = path.join(root, 'tools', 'hvigor');
  const javaHome = path.join(root, 'jdk');
  fs.mkdirSync(nativeRoot);
  fs.mkdirSync(path.join(hvigorHome, 'bin'), { recursive: true });
  fs.mkdirSync(path.join(javaHome, 'bin'), { recursive: true });
  fs.writeFileSync(path.join(javaHome, 'bin', process.platform === 'win32' ? 'java.exe' : 'java'), '');
  const installed = path.join(hvigorHome, 'bin', 'hvigorw.js');
  fs.writeFileSync(installed, `process.stdout.write(JSON.stringify({
    cwd: process.cwd(), args: process.argv.slice(2), path: process.env.PATH
  }));`);
  fs.copyFileSync(path.join(__dirname, '..', 'hvigorw.cjs'), path.join(nativeRoot, 'hvigorw.cjs'));
  const alias = path.join(root, 'workspace-native');
  fs.symlinkSync(nativeRoot, alias, process.platform === 'win32' ? 'junction' : 'dir');
  return { nativeRoot, hvigorHome, javaHome, installed, alias };
}

test('explicit Hvigor installation takes precedence over PATH', (t) => {
  const { hvigorHome, installed } = fixture(t);
  assert.equal(findHvigor({ HVIGOR_HOME: hvigorHome }), fs.realpathSync(installed));
});

test('linked launcher uses real native cwd and forwards arguments without a shell', (t) => {
  const { nativeRoot, hvigorHome, javaHome, alias } = fixture(t);
  const args = ['assembleHap', '-p', 'value with spaces', 'literal&value'];
  const result = spawnSync(process.execPath, [path.join(alias, 'hvigorw.cjs'), ...args], {
    cwd: alias,
    env: { ...process.env, HVIGOR_HOME: hvigorHome, JAVA_HOME: javaHome },
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.cwd, fs.realpathSync(nativeRoot));
  assert.deepEqual(output.args, args);
  assert.equal(output.path.split(path.delimiter)[0], path.join(javaHome, 'bin'));
});
