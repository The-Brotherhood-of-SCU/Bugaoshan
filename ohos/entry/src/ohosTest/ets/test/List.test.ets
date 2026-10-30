import abilityTest from './Ability.test'
import nativeUiTest from './NativeUi.test'
import courseNotificationsTest from './CourseNotifications.test'
import courseCardTest from './CourseCard.test'

export default function testsuite() {
  abilityTest()
  nativeUiTest()
  courseNotificationsTest()
  courseCardTest()
}
