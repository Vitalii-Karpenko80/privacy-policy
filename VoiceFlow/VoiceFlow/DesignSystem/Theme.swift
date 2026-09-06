import SwiftUI

/// Central palette + spacing, mirroring the VoiceFlow design canvas.
enum Theme {
    enum Palette {
        static let background = Color(hex: 0xF4F3F0)
        static let surface = Color.white
        static let ink = Color(hex: 0x17171C)
        static let inkSecondary = Color(hex: 0x8B8B93)
        static let inkFaint = Color(hex: 0xB4B4BB)
        static let hairline = Color(hex: 0xEFEEEA)

        static let accent = Color(hex: 0x5B54E6)
        static let accentSoft = Color(hex: 0xECEBFB)

        // Category tokens
        static let event = Color(hex: 0x2F6BFF)
        static let eventSoft = Color(hex: 0xE7EEFF)
        static let task = Color(hex: 0x12A574)
        static let taskSoft = Color(hex: 0xE1F4EC)
        static let note = Color(hex: 0xE0912B)
        static let noteSoft = Color(hex: 0xFBEEDA)
        static let contact = Color(hex: 0x9B4DDB)
        static let contactSoft = Color(hex: 0xF2E8FB)

        // Dark "listening" surface
        static let listeningBackground = Color(hex: 0x0C0C11)
    }

    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 16
        static let chip: CGFloat = 11
    }

    enum Spacing {
        static let screen: CGFloat = 20
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// Colour + SF Symbol per intent category, reused across cards.
extension IntentType {
    var accentColor: Color {
        switch self {
        case .calendarEvent, .meeting, .location: return Theme.Palette.event
        case .reminder, .call, .shopping, .followUp: return Theme.Palette.task
        case .note, .idea: return Theme.Palette.note
        case .contactReference, .message: return Theme.Palette.contact
        }
    }

    var softColor: Color {
        switch self {
        case .calendarEvent, .meeting, .location: return Theme.Palette.eventSoft
        case .reminder, .call, .shopping, .followUp: return Theme.Palette.taskSoft
        case .note, .idea: return Theme.Palette.noteSoft
        case .contactReference, .message: return Theme.Palette.contactSoft
        }
    }

    var symbolName: String {
        switch self {
        case .calendarEvent, .meeting: return "calendar"
        case .reminder, .followUp: return "checkmark.circle"
        case .note, .idea: return "note.text"
        case .contactReference: return "person"
        case .call: return "phone"
        case .message: return "message"
        case .location: return "mappin.and.ellipse"
        case .shopping: return "cart"
        }
    }
}
