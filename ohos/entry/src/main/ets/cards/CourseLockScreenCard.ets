import { CardView } from './CourseCardModel';

class OpenCourseAppAction {
  action: string = 'router';
  abilityName: string = 'EntryAbility';
}

@Entry
@Component
struct CourseLockScreenCard {
  @LocalStorageProp('model') model: CardView = new CardView();

  build() {
    Column({ space: 2 }) {
      Text(this.model.date || this.model.title || $r('app.string.card_title'))
        .fontSize(10).fontColor(Color.White).opacity(0.7).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.model.courses.length > 0) {
        Text(this.model.courses[0].name).fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Bold)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.model.courses[0].startTime}-${this.model.courses[0].endTime}  ${this.model.courses[0].location}`)
          .fontSize(11).fontColor(Color.White).opacity(0.85).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text(this.model.emptyText || $r('app.string.card_sync_hint'))
          .fontSize(12).fontColor(Color.White).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%').height('100%').padding(6)
    .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Transparent)
    .onClick(() => postCardAction(this, new OpenCourseAppAction()))
  }
}
