import fs from 'fs';
import path from 'path';
import { HvigorNode, HvigorPlugin } from '@ohos/hvigor';
import { OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';

type AppProfile = ReturnType<OhosAppContext['getBuildProfileOpt']>['app'];

interface LocalSigning {
  signingConfigs: AppProfile['signingConfigs'];
  products: Record<string, string>;
}

const mergeSigningConfig: (app: AppProfile, local: LocalSigning) => AppProfile =
  require('./signing-config.cjs').mergeSigningConfig;

/** Apply machine-local signing in memory; keep the tracked profile unsigned. */
export const localSigningPlugin: HvigorPlugin = {
  pluginId: 'bugaoshan-local-signing',
  apply(node: HvigorNode): void {
    // CPF's signed-HAP preflight also recognizes this machine-local file.
    const file = path.join(__dirname, '.sign', 'sign-config.json5');
    if (!fs.existsSync(file)) return;
    const local = JSON.parse(fs.readFileSync(file, 'utf8')) as LocalSigning;
    const context = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
    const profile = context.getBuildProfileOpt();
    profile.app = mergeSigningConfig(profile.app, local);
    context.setBuildProfileOpt(profile);
  },
};
