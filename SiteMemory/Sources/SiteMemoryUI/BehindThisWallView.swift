import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI

/// The payoff screen: "Behind this wall" — a list of everything recorded before
/// the surface was closed. In v2 this becomes the target of the live AR overlay
/// (`SpatialAnchoring.relocalize`); the list stays as the accessible fallback.
public struct BehindThisWallView: View {
    @StateObject private var model: WallMemoryViewModel

    public init(model: @autoclosure @escaping () -> WallMemoryViewModel) {
        _model = StateObject(wrappedValue: model())
    }

    public var body: some View {
        List {
            if model.rows.isEmpty && !model.isLoading {
                ContentUnavailableViewCompat(
                    title: "Nothing recorded yet",
                    systemImage: "camera.viewfinder",
                    description: "Photograph the open wall before it is closed to start its memory."
                )
            }
            ForEach(model.rows) { row in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(row.category.displayName).font(.headline)
                            if row.isMachineSuggested {
                                Image(systemName: "sparkles").foregroundStyle(.secondary)
                            }
                        }
                        Text(row.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: row.category.systemImage)
                        .foregroundStyle(row.category.tint)
                }
            }
        }
        .navigationTitle("Behind this wall")
        .overlay { if model.isLoading { ProgressView() } }
        .task { await model.load() }
        .alert(
            "Could not load",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

/// Small shim so the view compiles on OS versions predating
/// `ContentUnavailableView` (iOS 17). Replace with the system view once the
/// deployment target allows.
private struct ContentUnavailableViewCompat: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(description).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
#endif
