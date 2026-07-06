import { BusinessError } from '@kit.BasicServicesKit';
import { hidebug, hilog, hiTraceChain, hiTraceMeter, jsLeakWatcher } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct Index {
  @State cpuValue: string = '--';
  @State traceState: string = 'Ready';
  @State leakState: string = 'No alerts';
  @State traceDetail: string = 'capture unknown';

  private readonly traceLevel = hiTraceMeter.HiTraceOutputLevel.COMMERCIAL;

  private refreshCpu(): void {
    try {
      hiTraceMeter.startSyncTrace(this.traceLevel, 'TraceInspectorRefreshCpu', 'source=hidebug');
      const usage = hidebug.getSystemCpuUsage();
      this.cpuValue = `${Math.round(usage * 100)}%`;
      hiTraceMeter.traceByValue(this.traceLevel, 'TraceInspectorCpuPercent', Math.round(usage * 100));
      hilog.info(0x0000, 'TraceInspector', `CPU usage refreshed: ${this.cpuValue}`);
    } catch (err) {
      this.cpuValue = 'Error';
      hilog.error(0x0000, 'TraceInspector', `Failed to refresh CPU: ${(err as BusinessError).message}`);
    } finally {
      hiTraceMeter.finishSyncTrace(this.traceLevel);
    }
  }

  private runTraceFlow(): void {
    const taskId = Date.now() % 100000;
    const captureState = hiTraceMeter.isTraceEnabled() ? 'capture on' : 'capture off';
    let traceId = hiTraceChain.begin('TraceInspectorFlow', hiTraceChain.HiTraceFlag.INCLUDE_ASYNC);

    try {
      hiTraceMeter.startAsyncTrace(this.traceLevel, 'TraceInspectorRequest', taskId, 'trace-inspector',
        'stage=watch');
      hiTraceChain.tracepoint(hiTraceChain.HiTraceCommunicationMode.DEVICE,
        hiTraceChain.HiTraceTracepointType.CS, traceId, 'watch request start');

      let phoneSpan = hiTraceChain.createSpan();
      hiTraceChain.setId(phoneSpan);
      hiTraceChain.tracepoint(hiTraceChain.HiTraceCommunicationMode.DEVICE,
        hiTraceChain.HiTraceTracepointType.SS, phoneSpan, 'phone span linked');

      let cloudSpan = hiTraceChain.createSpan();
      hiTraceChain.setId(cloudSpan);
      hiTraceChain.tracepoint(hiTraceChain.HiTraceCommunicationMode.DEVICE,
        hiTraceChain.HiTraceTracepointType.SR, cloudSpan, 'cloud span finished');

      hiTraceMeter.traceByValue(this.traceLevel, 'TraceInspectorHopCount', 3);
      hiTraceMeter.finishAsyncTrace(this.traceLevel, 'TraceInspectorRequest', taskId);

      this.traceState = 'Done';
      this.traceDetail = `${captureState}, task ${taskId}`;
      hilog.info(0x0000, 'TraceInspector', `Trace flow completed, taskId: ${taskId}`);
    } catch (err) {
      this.traceState = 'Error';
      this.traceDetail = 'Trace failed';
      hilog.error(0x0000, 'TraceInspector', `Trace flow failed: ${(err as BusinessError).message}`);
    } finally {
      if (hiTraceChain.isValid(traceId)) {
        hiTraceChain.setId(traceId);
        hiTraceChain.end(traceId);
      }
    }
  }

  private startLeakWatcher(): void {
    try {
      let config: Array<string> = [];
      jsLeakWatcher.enableLeakWatcher(true, config, (filePath: Array<string>) => {
        if (filePath.length >= 2) {
          this.leakState = 'Dump ready';
          hilog.info(0x0000, 'TraceInspector', `Leak watcher list: ${filePath[0]}`);
          hilog.info(0x0000, 'TraceInspector', `Leak watcher heap: ${filePath[1]}`);
        } else {
          this.leakState = 'No dump';
          hilog.info(0x0000, 'TraceInspector', 'Leak watcher callback returned no dump file');
        }
      });
      this.leakState = 'Watching';
      hilog.info(0x0000, 'TraceInspector', 'Leak watcher enabled');
    } catch (err) {
      this.leakState = 'Error';
      hilog.error(0x0000, 'TraceInspector', `Leak watcher failed: ${(err as BusinessError).message}`);
    }
  }

  build() {
    Stack() {
      Column() {
        Text('Trace Inspector')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6, bottom: 10 })

        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('CPU')
              .fontSize(10)
              .fontColor('#6B7280')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.cpuValue)
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 10, right: 10 })
          .height(58)
          .width('48%')
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .border({ width: 1, color: '#E5E7EB' })

          Column({ space: 2 }) {
            Text('Trace')
              .fontSize(10)
              .fontColor('#6B7280')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.traceState)
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 10, right: 10 })
          .height(58)
          .width('48%')
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .border({ width: 1, color: '#E5E7EB' })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Row({ space: 6 }) {
          Button('CPU')
            .type(ButtonType.Capsule)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#0F766E')
            .height(34)
            .width('31%')
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.refreshCpu();
            })
          Button('Trace')
            .type(ButtonType.Capsule)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#2563EB')
            .height(34)
            .width('31%')
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.runTraceFlow();
            })
          Button('Leak')
            .type(ButtonType.Capsule)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#B45309')
            .height(34)
            .width('31%')
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.startLeakWatcher();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8, bottom: 6 })

        Column({ space: 2 }) {
          Text('Latest Trace')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.traceDetail)
            .fontSize(11)
            .fontColor('#4B5563')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(44)
        .padding({ left: 8, right: 8 })
        .borderRadius(8)
        .backgroundColor(Color.White)
        .border({ width: 1, color: '#E5E7EB' })

        Text(`Leak: ${this.leakState}`)
          .fontSize(10)
          .fontColor('#92400E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
      }
      .width('88%')
      .height('88%')
      .alignItems(HorizontalAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#EEF2F7')
  }
}
