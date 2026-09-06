import Foundation

/// A candidate contact matched from the address book for a spoken name.
struct ContactMatch: Identifiable, Equatable, Hashable {
    /// `CNContact.identifier`.
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumber: String?

    var displayName: String {
        [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var initials: String {
        let first = givenName.first.map(String.init) ?? ""
        let last = familyName.first.map(String.init) ?? ""
        let combined = (first + last)
        return combined.isEmpty ? "?" : combined.uppercased()
    }
}
