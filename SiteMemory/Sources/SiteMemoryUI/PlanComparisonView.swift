import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension ComparisonStatus {
    /// Colour coding shared by the overlay and the legend.
    var color: Color {
        switch self {
        case .match: return .green
        case .outOfTolerance: return .orange
        case .missing: return .red
        case .extra: return .purple
        }
    }

    var label: String {
        switch self {
        case .match: return "On plan"
        case .outOfTolerance: return "Out of tolerance"
        case .missing: return "Missing"
        case .extra: return "Off-plan"
        }
    }
}

/// "Project vs reality": the plan with planned positions (hollow) and as-built
/// positions (filled) drawn on top, connected by a line labelled with the real
/// deviation. Colour tells the story at a glance.
public struct PlanComparisonView: View {
    @StateObject private var model: PlanComparisonViewModel

    public init(model: @autoclosure @escaping () -> PlanComparisonViewModel) {
        _model = StateObject(wrappedValue: model())
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let summary = model.summary { summaryHeader(summary) }
            overlayCanvas
            legend
        }
        .overlay { if model.isLoading { ProgressView() } }
        .task { await model.load() }
        .alert(
            "Comparison unavailable",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }

    private func summaryHeader(_ summary: PlanComparisonViewModel.Summary) -> some View {
        HStack(spacing: 16) {
            stat("\(summary.completionPercent)%", "Complete")
            stat("\(summary.withinTolerance)", "On plan", .green)
            stat("\(summary.outOfTolerance)", "Off tol.", .orange)
            stat("\(summary.missing)", "Missing", .red)
            stat("\(summary.extra)", "Off-plan", .purple)
            if let worst = summary.worstDeviation {
                stat(worst, "Worst Δ")
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private func stat(_ value: String, _ caption: String, _ tint: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(tint)
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var overlayCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                planImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                Canvas { context, size in
                    for element in model.elements {
                        draw(element, in: &context, size: size)
                    }
                }
            }
        }
        .aspectRatio(planAspectRatio, contentMode: .fit)
    }

    private func draw(_ element: PlanOverlayElement, in context: inout GraphicsContext, size: CGSize) {
        let color = element.status.color
        let planned = element.plannedPoint.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let asBuilt = element.asBuiltPoint.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

        if let planned, let asBuilt {
            var line = Path()
            line.move(to: planned)
            line.addLine(to: asBuilt)
            context.stroke(line, with: .color(color), lineWidth: 2)
            if let deviation = element.deviation {
                let mid = CGPoint(x: (planned.x + asBuilt.x) / 2, y: (planned.y + asBuilt.y) / 2)
                var text = context.resolve(Text(deviation.formatted(model.unitSystem)).font(.caption2))
                text.shading = .color(color)
                context.draw(text, at: CGPoint(x: mid.x, y: mid.y - 8), anchor: .center)
            }
        }

        // Planned: hollow ring. As-built: filled dot.
        if let planned {
            context.stroke(ringPath(at: planned, radius: 6), with: .color(color), lineWidth: 2)
        }
        if let asBuilt {
            context.fill(ringPath(at: asBuilt, radius: 5), with: .color(color))
        }
    }

    private func ringPath(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([ComparisonStatus.match, .outOfTolerance, .missing, .extra], id: \.self) { status in
                HStack(spacing: 4) {
                    Circle().fill(status.color).frame(width: 8, height: 8)
                    Text(status.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
    }

    private var planAspectRatio: CGFloat {
        let size = model.sheet.pageSize
        guard size.pixelHeight > 0 else { return 1 }
        return CGFloat(size.pixelWidth / size.pixelHeight)
    }

    private var planImage: Image {
        let placeholder = Image(systemName: "doc.richtext")
        guard let data = model.pageImageData else { return placeholder }
        #if canImport(UIKit)
        return UIImage(data: data).map(Image.init(uiImage:)) ?? placeholder
        #elseif canImport(AppKit)
        return NSImage(data: data).map(Image.init(nsImage:)) ?? placeholder
        #else
        return placeholder
        #endif
    }
}
#endif
