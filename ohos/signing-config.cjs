// A DevEco signing refresh must take precedence over saved machine-local values.
function mergeSigningConfig(app, local) {
  const configurations = new Map();
  for (const config of local.signingConfigs ?? []) configurations.set(config.name, config);
  for (const config of app.signingConfigs ?? []) configurations.set(config.name, config);
  return {
    ...app,
    signingConfigs: [...configurations.values()],
    products: (app.products ?? []).map(product => {
      if (product.signingConfig) return product;
      const name = local.products?.[product.name];
      return name && configurations.has(name)
        ? { ...product, signingConfig: name }
        : product;
    }),
  };
}

module.exports = { mergeSigningConfig };
