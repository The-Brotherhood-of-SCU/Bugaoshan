import { CardCourse, CardView } from './CourseCardModel';

class OpenCourseAppAction {
  action: string = 'router';
  abilityName: string = 'EntryAbility';
}

@Entry
@Component
struct CourseCard {
  @LocalStorageProp('model') model: CardView = new CardView();
  @State cardWidth: number = 0;
  @State cardHeight: number = 0;

  private oneLineTitle(): boolean {
    return this.cardWidth - 24 >= 180;
  }

  private expanded(): boolean {
    return !this.model.compact && this.cardHeight - 80 - 24 > 100;
  }

  private accent(course: CardCourse): ResourceColor {
    if (this.model.monochrome) return $r('app.color.card_primary');
    return this.model.tomorrow ? $r('app.color.card_tomorrow_accent') : course.color;
  }

  private metadataColor(course: CardCourse): ResourceColor {
    if (course.inProgress) return this.accent(course);
    return this.model.tomorrow ? $r('app.color.card_tomorrow_secondary') : $r('app.color.card_secondary');
  }

  private openApp(): void {
    postCardAction(this, new OpenCourseAppAction());
  }

  @Builder
  courseRow(course: CardCourse) {
    Row({ space: this.model.compact ? 6 : 10 }) {
      Column() {}
        .width(4).height(36).borderRadius(2).backgroundColor(this.accent(course))
      Column({ space: 2 }) {
        Text(course.name)
          .fontSize(14).fontWeight(course.inProgress ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.model.tomorrow ? $r('app.color.card_tomorrow_primary') : $r('app.color.card_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        if (this.expanded()) {
          Row({ space: 4 }) {
            Text(`${course.startTime} - ${course.endTime}`)
              .fontSize(13).fontColor(this.metadataColor(course)).maxLines(1).layoutWeight(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.oneLineTitle() && course.section !== '') {
              Text(course.section).fontSize(11).maxLines(1)
                .fontColor(this.model.tomorrow ? $r('app.color.card_tomorrow_secondary') : $r('app.color.card_secondary'))
            }
          }.width('100%')
          Text(course.location).fontSize(13).maxLines(2).width('100%')
            .fontColor(this.model.tomorrow ? $r('app.color.card_tomorrow_secondary') : $r('app.color.card_secondary'))
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text(this.model.compact ? `${course.startTime} - ${course.endTime}` :
            `${this.cardWidth < 200 ? course.startTime : `${course.startTime} - ${course.endTime}`}  ${course.location}`)
            .fontSize(this.cardWidth < 200 ? 11 : 13).fontColor(this.metadataColor(course))
            .maxLines(this.model.compact ? 1 : 2).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(this.model.compact ? 4 : 8).borderRadius(12).backgroundColor($r('app.color.card_surface'))
  }

  build() {
    Column({ space: 10 }) {
      if (this.oneLineTitle()) {
        Row({ space: 4 }) {
          Text(this.model.title || $r('app.string.card_title'))
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(this.model.monochrome ? $r('app.color.card_primary') : $r('app.color.card_accent'))
            .maxLines(1).layoutWeight(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.model.date).fontSize(11).fontColor($r('app.color.card_secondary')).maxLines(1)
        }.width('100%')
      } else {
        Column({ space: 2 }) {
          Text(this.model.title || $r('app.string.card_title'))
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(this.model.monochrome ? $r('app.color.card_primary') : $r('app.color.card_accent'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.model.date).fontSize(11).fontColor($r('app.color.card_secondary')).maxLines(1)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
      if (this.model.courses.length === 0) {
        Text(this.model.emptyText || $r('app.string.card_sync_hint'))
          .fontSize(13).fontColor($r('app.color.card_secondary')).textAlign(TextAlign.Center)
          .width('100%').layoutWeight(1)
      } else {
        List() {
          ForEach(this.model.courses, (course: CardCourse) => {
            ListItem() { this.courseRow(course) }.padding({ top: 2, bottom: 2 })
          }, (course: CardCourse) => course.id)
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%').height('100%').padding(12).borderRadius(16).clip(true)
    .alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.card_background'))
    .onClick(() => this.openApp())
    // Form cards support onSizeChange (API 12+), but not onAreaChange.
    .onSizeChange((_oldSize: SizeOptions, newSize: SizeOptions) => {
      const width = Number(newSize.width);
      const height = Number(newSize.height);
      if (Number.isFinite(width) && width > 0 && width !== this.cardWidth) {
        this.cardWidth = width;
      }
      if (Number.isFinite(height) && height > 0 && height !== this.cardHeight) {
        this.cardHeight = height;
      }
    })
  }
}
