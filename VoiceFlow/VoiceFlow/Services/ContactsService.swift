import Foundation
import Contacts

/// Searches the address book for people mentioned in a command (ТЗ §10, §11).
///
/// Privacy: matching happens **on device**; only candidate names are ever passed
/// to the AI, never the whole address book.
struct ContactsService {
    let store: CNContactStore

    private let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor
    ]

    /// Returns contacts matching a spoken name (given name match is enough).
    func candidates(for name: String) -> [ContactMatch] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let predicate = CNContact.predicateForContacts(matchingName: trimmed)
        let contacts = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys)) ?? []

        return contacts.map { contact in
            ContactMatch(
                id: contact.identifier,
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneNumber: contact.phoneNumbers.first?.value.stringValue
            )
        }
    }

    func contact(withIdentifier id: String) -> ContactMatch? {
        guard let contact = try? store.unifiedContact(withIdentifier: id, keysToFetch: keys) else {
            return nil
        }
        return ContactMatch(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            phoneNumber: contact.phoneNumbers.first?.value.stringValue
        )
    }
}
