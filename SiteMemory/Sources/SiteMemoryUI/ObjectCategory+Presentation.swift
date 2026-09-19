import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI

/// Presentation lives in the UI target so Core stays free of SF Symbols and
/// localized strings. The display name is pulled from the module bundle so the
/// EU/NA localizations (de, fr, es, en-GB, en-US, …) can be added as
/// `Localizable.strings` without code changes.
public extension ObjectCategory {
    var displayName: LocalizedStringKey { LocalizedStringKey(localizationKey) }

    var systemImage: String {
        switch self {
        case .electricalCable, .electricalConduit: return "bolt"
        case .junctionBox, .socketBackBox: return "poweroutlet.type.f"
        case .waterPipe, .drainPipe: return "drop"
        case .gasPipe: return "flame"
        case .underfloorHeating: return "thermometer.medium"
        case .ventilationDuct: return "wind"
        case .metalStud: return "ruler"
        case .woodFrame: return "square.split.bottomrightquarter"
        case .embed: return "square.dashed"
        case .insulation: return "square.grid.3x3.square"
        case .vaporBarrier: return "square.on.square"
        case .other: return "questionmark.square.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .electricalCable, .electricalConduit, .junctionBox, .socketBackBox: return .yellow
        case .waterPipe, .drainPipe, .underfloorHeating: return .blue
        case .gasPipe: return .orange
        case .ventilationDuct: return .teal
        case .metalStud, .woodFrame, .embed: return .brown
        default: return .secondary
        }
    }
}
#endif
