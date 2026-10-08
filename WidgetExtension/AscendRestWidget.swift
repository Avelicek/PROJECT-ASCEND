import ActivityKit
import WidgetKit
import SwiftUI

@main struct AscendRestWidgets: WidgetBundle { var body: some Widget { AscendRestWidget() } }
struct AscendRestWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: context.isStale ? "checkmark.circle" : "timer").font(.title2).foregroundStyle(.gray)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.sessionTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(context.state.exercise).font(.headline).lineLimit(1)
                    Text(context.isStale ? "Rest complete · ready when you are" : context.state.target).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                countdown(context).font(.title2.monospacedDigit()).frame(maxWidth: 90)
            }.padding(16).activityBackgroundTint(Color(red: 0.03, green: 0.04, blue: 0.065)).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("ASCEND", systemImage: "dumbbell").font(.caption) }
                DynamicIslandExpandedRegion(.trailing) { countdown(context).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) { VStack(alignment: .leading, spacing: 4) { Text(context.state.exercise).font(.headline); Text(context.isStale ? "Rest complete" : context.state.target).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }
            } compactLeading: { Image(systemName: context.isStale ? "checkmark" : "timer") }
            compactTrailing: { countdown(context).monospacedDigit().frame(width: 48) }
            minimal: { Image(systemName: context.isStale ? "checkmark" : "timer") }
            .keylineTint(.gray)
        }
    }
    @ViewBuilder private func countdown(_ context: ActivityViewContext<RestActivityAttributes>) -> some View {
        if context.isStale { Text("Ready") }
        else { Text(timerInterval: context.state.startedAt...max(context.state.startedAt, context.state.restEndsAt), countsDown: true).multilineTextAlignment(.trailing) }
    }
}
