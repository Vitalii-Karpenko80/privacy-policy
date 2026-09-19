import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The floor-plan board: the imported PDF page with pinned photos/walls on top,
/// each labelled with its real position once the sheet is calibrated. A tap on
/// the plan reports a normalized point so the host can start a placement.
public struct PlanBoardView: View {
    @StateObject private var model: PlanBoardViewModel
    /// Called with the tapped normalized point (host decides what to pin there).
    private let onTapPlan: (NormalizedPoint) -> Void

    public init(
        model: @autoclosure @escaping () -> PlanBoardViewModel,
        onTapPlan: @escaping (NormalizedPoint) -> Void = { _ in }
    ) {
        _model = StateObject(wrappedValue: model())
        self.onTapPlan = onTapPlan
    }

    public var body: some View {
        VStack(spacing: 0) {
            planCanvas
            if !model.isCalibrated {
                Label("Set the plan scale: tap two points a known distance apart.",
                      systemImage: "ruler")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            List(model.pins) { pin in
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.title).font(.headline)
                    Text(pin.detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .overlay { if model.isLoading { ProgressView() } }
        .task { await model.load() }
        .alert(
            "Could not load plan",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }

    private var planCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                planImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(model.pins) { pin in
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                        .position(
                            x: pin.point.x * geo.size.width,
                            y: pin.point.y * geo.size.height
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard geo.size.width > 0, geo.size.height > 0 else { return }
                onTapPlan(
                    NormalizedPoint(
                        x: location.x / geo.size.width,
                        y: location.y / geo.size.height
                    )
                )
            }
        }
        .aspectRatio(planAspectRatio, contentMode: .fit)
    }

    private var planAspectRatio: CGFloat {
        let size = model.sheet.pageSize
        guard size.pixelHeight > 0 else { return 1 }
        return CGFloat(size.pixelWidth / size.pixelHeight)
    }

    // Plain `Image` (not @ViewBuilder) so `.resizable()` is available on it.
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
