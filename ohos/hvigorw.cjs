// Hvigor rejects symlinked module paths. CPF invokes this launcher through
// .flutter-workspace/ohos; start the installed Hvigor in the real native root.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

function findHvigor(env = process.env) {
  const candidates = [];
  if (env.HVIGOR_HOME) candidates.push(path.join(env.HVIGOR_HOME, 'bin', 'hvigorw.js'));
  for (const nodeHome of [env.NODE_HOME, path.dirname(process.execPath)]) {
    if (nodeHome) candidates.push(path.join(nodeHome, '..', 'hvigor', 'bin', 'hvigorw.js'));
  }
  for (const directory of (env.PATH || env.Path || '').split(path.delimiter)) {
    if (directory) candidates.push(path.join(directory, 'hvigorw.js'));
  }
  const found = candidates.find(candidate => fs.existsSync(candidate));
  if (!found) throw new Error('Hvigor not found. Add the DevEco hvigor/bin directory to PATH or set HVIGOR_HOME.');
  return fs.realpathSync(found);
}

function runHvigor(args) {
  const executable = findHvigor();
  const env = { ...process.env };
  // Hvigor's packager invokes `java` via PATH, even when JAVA_HOME is set.
  const bundledJdk = path.resolve(path.dirname(executable), '..', '..', '..', 'jbr');
  const javaHome = env.JAVA_HOME || bundledJdk;
  if (fs.existsSync(path.join(javaHome, 'bin', process.platform === 'win32' ? 'java.exe' : 'java'))) {
    env.JAVA_HOME = javaHome;
    env.PATH = `${path.join(javaHome, 'bin')}${path.delimiter}${env.PATH || env.Path || ''}`;
    delete env.Path;
  }
  const result = spawnSync(process.execPath, [executable, ...args], {
    cwd: fs.realpathSync(__dirname),
    stdio: 'inherit',
    env,
  });
  if (result.error) throw result.error;
  return result.status ?? 1;
}

module.exports = { findHvigor, runHvigor };

if (require.main === module) {
  try {
    process.exitCode = runHvigor(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
