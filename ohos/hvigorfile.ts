import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { linkedFlutterPlugin } from './tool/flutter_project';

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins: [
        linkedFlutterPlugin(__dirname),
    ]
}
