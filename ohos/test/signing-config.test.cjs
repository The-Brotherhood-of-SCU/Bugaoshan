const assert = require('node:assert/strict');
const { test } = require('node:test');
const { mergeSigningConfig } = require('../signing-config.cjs');

test('a DevEco refresh wins over a saved profile with the same signing name', () => {
  const latest = { name: 'default', material: { profile: 'new-profile.p7b' } };
  const app = { signingConfigs: [latest], products: [{ name: 'default' }] };
  const local = {
    signingConfigs: [{ name: 'default', material: { profile: 'old-profile.p7b' } }],
    products: { default: 'default' },
  };
  const merged = mergeSigningConfig(app, local);
  assert.deepEqual(merged.signingConfigs, [latest]);
  assert.equal(merged.products[0].signingConfig, 'default');
  assert.equal(local.signingConfigs[0].material.profile, 'old-profile.p7b');
  assert.equal(app.products[0].signingConfig, undefined);
});

test('explicit DevEco product selection wins over the saved product mapping', () => {
  const app = {
    signingConfigs: [{ name: 'release' }],
    products: [{ name: 'default', signingConfig: 'release' }],
  };
  const merged = mergeSigningConfig(app, {
    signingConfigs: [{ name: 'debug' }], products: { default: 'debug' },
  });
  assert.equal(merged.products[0].signingConfig, 'release');
  assert.deepEqual(merged.signingConfigs.map(config => config.name), ['debug', 'release']);
});

test('unsigned repository baseline uses the saved local signing configuration', () => {
  const local = {
    signingConfigs: [{ name: 'default', material: { profile: 'local.p7b' } }],
    products: { default: 'default' },
  };
  const merged = mergeSigningConfig({ signingConfigs: [], products: [{ name: 'default' }] }, local);
  assert.deepEqual(merged.signingConfigs, local.signingConfigs);
  assert.equal(merged.products[0].signingConfig, 'default');
});

test('merging signing preserves capabilities and SDK settings', () => {
  const capabilities = [{ bundleName: 'example.app', config: [{ capability: 'agentreminder' }] }];
  const merged = mergeSigningConfig({
    capabilities,
    products: [{ name: 'default', targetSdkVersion: '26.0.0' }],
  }, { signingConfigs: [], products: { default: 'missing' } });
  assert.deepEqual(merged.capabilities, capabilities);
  assert.equal(merged.products[0].targetSdkVersion, '26.0.0');
  assert.equal(merged.products[0].signingConfig, undefined);
});
