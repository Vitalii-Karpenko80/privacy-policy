import Foundation

/// Which measurement system a distance is presented in.
///
/// SiteMemory stores every distance internally in metres (SI) and only formats
/// into millimetres or inches/feet at the edge. That keeps the geometry math
/// single-unit and makes EU (mm) and North American (inch/foot) markets a pure
/// presentation concern.
public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case metric   // millimetres / metres
    case imperial // inches / feet

    /// A reasonable default for a country code (ISO 3166-1 alpha-2).
    public static func `default`(forCountryCode code: String?) -> UnitSystem {
        switch code?.uppercased() {
        case "US", "LR", "MM": return .imperial
        default: return .metric
        }
    }
}

/// A length, stored canonically in metres.
///
/// A dedicated type (rather than a bare `Double`) prevents the classic
/// "was that mm or metres?" bug and gives us one place to format for display.
public struct Length: Codable, Hashable, Comparable, Sendable {
    public let metres: Double

    public init(metres: Double) { self.metres = metres }

    public static func metres(_ v: Double) -> Length { Length(metres: v) }
    public static func millimetres(_ v: Double) -> Length { Length(metres: v / 1_000) }
    public static func centimetres(_ v: Double) -> Length { Length(metres: v / 100) }
    public static func inches(_ v: Double) -> Length { Length(metres: v * 0.0254) }
    public static func feet(_ v: Double) -> Length { Length(metres: v * 0.3048) }

    public var millimetres: Double { metres * 1_000 }
    public var inches: Double { metres / 0.0254 }

    public static func < (lhs: Length, rhs: Length) -> Bool { lhs.metres < rhs.metres }
    public static func + (lhs: Length, rhs: Length) -> Length { .metres(lhs.metres + rhs.metres) }
    public static func - (lhs: Length, rhs: Length) -> Length { .metres(lhs.metres - rhs.metres) }

    /// Human-facing string, e.g. `"320 mm"` or `"1' 0\""`.
    public func formatted(_ system: UnitSystem) -> String {
        switch system {
        case .metric:
            // Under 1 m read best in mm on site; above that, metres.
            if abs(metres) < 1 {
                return "\(Int(millimetres.rounded())) mm"
            }
            return String(format: "%.2f m", metres)
        case .imperial:
            let totalInches = inches
            let feet = Int((totalInches / 12).rounded(.towardZero))
            let inchRemainder = totalInches - Double(feet) * 12
            if feet == 0 {
                return String(format: "%.1f\"", inchRemainder)
            }
            return String(format: "%d' %.0f\"", feet, inchRemainder)
        }
    }
}
