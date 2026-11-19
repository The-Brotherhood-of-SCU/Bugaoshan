import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { flutterHvigorPlugin } from 'flutter-hvigor-plugin';
import { localSigningPlugin } from './local-signing';
const { projectPath } = require('./flutterw.cjs');

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins: [localSigningPlugin, flutterHvigorPlugin(projectPath)]
}
