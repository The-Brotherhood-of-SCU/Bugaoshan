import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formInfo from '@ohos.app.form.formInfo';
import { Want } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import i18n from '@ohos.i18n';
import { CardBinding, CourseSnapshot, makeCardView } from './CourseCardModel';
import { CourseCardStore } from './CourseCardStore';

export default class CourseFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    try {
      const store = new CourseCardStore(this.context);
      const rawId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
      // Form IDs are 64-bit strings. Never convert through a JavaScript number.
      if (typeof rawId === 'string') {
        store.remember(rawId);
        // Give the form host time to register the new instance before updateForm.
        setTimeout(() => {
          this.refresh(rawId);
        }, 200);
      }
      return store.bindingData();
    } catch (error) {
      hilog.error(0x0000, 'CourseCard', 'Add form failed: %{public}s', (error as Error).message);
      return formBindingData.createFormBindingData(
        new CardBinding(makeCardView(new CourseSnapshot(), i18n.System.getSystemLanguage())));
    }
  }

  onUpdateForm(formId: string): void {
    this.refresh(formId);
  }

  onCastToNormalForm(formId: string): void {
    this.refresh(formId);
  }

  private async refresh(formId: string): Promise<void> {
    try {
      const store = new CourseCardStore(this.context);
      await store.refresh(formId);
    } catch (error) {
      hilog.error(0x0000, 'CourseCard', 'Refresh form failed: %{public}s', (error as Error).message);
    }
  }

  onRemoveForm(formId: string): void {
    try {
      new CourseCardStore(this.context).forget(formId);
    } catch (error) {
      hilog.warn(0x0000, 'CourseCard', 'Remove form failed: %{public}s', (error as Error).message);
    }
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
