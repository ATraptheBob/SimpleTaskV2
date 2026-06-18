import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            PomodoroLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                            .foregroundColor(context.state.isBreak ? .green : .pink)
                        Text(context.state.isBreak ? "Break" : "Focus")
                            .font(.subheadline).bold()
                            .foregroundColor(context.state.isBreak ? .green : .pink)
                    }
                    .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if let endTime = context.state.timerEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .font(.title2.bold().monospacedDigit())
                            .foregroundColor(context.state.isBreak ? .green : .pink)
                            .padding(.top, 8)
                    } else {
                        Text("PAUSED")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.subject)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        // Interactive Button inside Dynamic Island (Requires AppIntent)
                        // Button(intent: ToggleTimerIntent()) {
                        //     Image(systemName: context.state.timerEndTime != nil ? "pause.circle.fill" : "play.circle.fill")
                        //         .font(.title2)
                        // }
                        // .tint(context.state.isBreak ? .green : .pink)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .foregroundColor(context.state.isBreak ? .green : .pink)
            } compactTrailing: {
                if let endTime = context.state.timerEndTime {
                    Text(timerInterval: Date()...endTime, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 40)
                        .foregroundColor(context.state.isBreak ? .green : .pink)
                } else {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.gray)
                }
            } minimal: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .foregroundColor(context.state.isBreak ? .green : .pink)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(context.state.isBreak ? Color.green : Color.pink)
        }
    }
}

struct PomodoroLiveActivityView: View {
    let context: ActivityViewContext<PomodoroAttributes>
    @Environment(\.isActivityFullscreen) var isActivityFullscreen

    var body: some View {
        if isActivityFullscreen {
            // ---------------------------------------------------------
            // STANDBY MODE UI — Progress Ring + Glowing Timer
            // ---------------------------------------------------------
            let accentColor: Color = context.state.isBreak ? .green : .pink
            let progress: Double = {
                guard let endTime = context.state.timerEndTime else { return 0 }
                let remaining = endTime.timeIntervalSince(Date())
                let total = Double(context.attributes.sessionDuration)
                guard total > 0 else { return 0 }
                return max(0, min(1, remaining / total))
            }()
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Subject label
                    HStack(spacing: 8) {
                        Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                            .font(.system(size: 14, weight: .semibold))
                        Text(context.state.isBreak ? "Break Time" : context.state.subject)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.15))
                    )
                    .padding(.bottom, 12)
                    
                    // Progress ring + timer
                    ZStack {
                        // Outer track ring (dim)
                        Circle()
                            .stroke(accentColor.opacity(0.12), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 180, height: 180)
                        
                        // Progress arc (bright)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        accentColor.opacity(0.4),
                                        accentColor,
                                        accentColor
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360 * progress)
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: accentColor.opacity(0.6), radius: 8)
                        
                        // Glow dot at the tip of the arc
                        Circle()
                            .fill(accentColor)
                            .frame(width: 10, height: 10)
                            .shadow(color: accentColor, radius: 6)
                            .offset(y: -90)
                            .rotationEffect(.degrees(360 * progress - 90))
                            .opacity(progress > 0.01 ? 1 : 0)
                        
                        // Timer text
                        if let endTime = context.state.timerEndTime {
                            Text(timerInterval: Date()...endTime, countsDown: true)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.6)
                        } else {
                            Text("PAUSED")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
            .activityBackgroundTint(.black)
        } else {
            // ---------------------------------------------------------
            // STANDARD LOCK SCREEN UI
            // ---------------------------------------------------------
            ZStack {
                Color(white: 0.1) // Glassy dark background
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(context.state.isBreak ? Color.green.opacity(0.2) : Color.pink.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                            .foregroundColor(context.state.isBreak ? .green : .pink)
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.isBreak ? "Break Time" : "Focus Session")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(context.state.subject)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if let endTime = context.state.timerEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(context.state.isBreak ? .green : .pink)
                            .frame(width: 90)
                    } else {
                        Text("PAUSED")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(Color.white)
        }
    }
}
