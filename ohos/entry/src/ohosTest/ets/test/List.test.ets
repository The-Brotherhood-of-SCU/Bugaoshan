import nativeUiTest from './NativeUi.test'
import courseNotificationsTest from './CourseNotifications.test'
import courseCardTest from './CourseCard.test'

export default function testsuite() {
  nativeUiTest()
  courseNotificationsTest()
  courseCardTest()
}
