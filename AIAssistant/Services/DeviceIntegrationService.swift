import Foundation
import EventKit
import Contacts
import CoreLocation
import Observation

// MARK: - DeviceCapability result

enum DeviceActionResult {
    case success(String)
    case failure(String)
}

// MARK: - DeviceIntegrationService

@Observable
@MainActor
final class DeviceIntegrationService {

    // Permissions state
    var calendarAuthorized = false
    var remindersAuthorized = false
    var contactsAuthorized = false

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    // MARK: - Request permissions

    func requestAllPermissions() async {
        await requestCalendarAccess()
        await requestRemindersAccess()
        await requestContactsAccess()
    }

    func requestCalendarAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            calendarAuthorized = granted
        } catch {
            calendarAuthorized = false
        }
    }

    func requestRemindersAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            remindersAuthorized = granted
        } catch {
            remindersAuthorized = false
        }
    }

    func requestContactsAccess() async {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            contactsAuthorized = granted
        } catch {
            contactsAuthorized = false
        }
    }

    // MARK: - Calendar

    /// Returns a text summary of upcoming events (next N days)
    func upcomingEvents(days: Int = 7) -> String {
        guard calendarAuthorized else { return "Sin acceso al calendario." }

        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        if events.isEmpty { return "No hay eventos próximos en los próximos \(days) días." }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return events.prefix(10).map { event in
            "• \(event.title ?? "Sin título") — \(formatter.string(from: event.startDate))"
        }.joined(separator: "\n")
    }

    /// Creates a calendar event
    func createEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil) -> DeviceActionResult {
        guard calendarAuthorized else { return .failure("Sin acceso al calendario.") }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            return .success("Evento '\(title)' creado correctamente.")
        } catch {
            return .failure("Error al crear evento: \(error.localizedDescription)")
        }
    }

    // MARK: - Reminders

    func pendingReminders() async -> String {
        guard remindersAuthorized else { return "Sin acceso a Recordatorios." }

        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders, !reminders.isEmpty else {
                    continuation.resume(returning: "No hay recordatorios pendientes.")
                    return
                }
                let text = reminders.prefix(10).map { r in
                    "• \(r.title ?? "Sin título")"
                }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
        }
    }

    func createReminder(title: String, dueDate: Date? = nil, notes: String? = nil) -> DeviceActionResult {
        guard remindersAuthorized else { return .failure("Sin acceso a Recordatorios.") }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let date = dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            reminder.dueDateComponents = components
        }

        do {
            try eventStore.save(reminder, commit: true)
            return .success("Recordatorio '\(title)' creado.")
        } catch {
            return .failure("Error al crear recordatorio: \(error.localizedDescription)")
        }
    }

    // MARK: - Contacts

    func searchContacts(query: String) -> String {
        guard contactsAuthorized else { return "Sin acceso a Contactos." }

        let request = CNContactFetchRequest(keysToFetch: [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ])
        request.predicate = CNContact.predicateForContacts(matchingName: query)

        var results: [String] = []
        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                let phones = contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: ", ")
                let emails = contact.emailAddresses.map { $0.value as String }.joined(separator: ", ")
                var line = "• \(name)"
                if !phones.isEmpty { line += " | 📞 \(phones)" }
                if !emails.isEmpty { line += " | ✉️ \(emails)" }
                results.append(line)
            }
        } catch { return "Error al buscar contactos." }

        return results.isEmpty ? "No se encontró '\(query)' en Contactos." : results.joined(separator: "\n")
    }

    // MARK: - Context summary for AI

    /// Returns a system-level context string to inject into the AI about the user's device state
    func deviceContextSummary() async -> String {
        var parts: [String] = []

        if calendarAuthorized {
            parts.append("📅 Próximos eventos:\n\(upcomingEvents(days: 3))")
        }
        if remindersAuthorized {
            let reminders = await pendingReminders()
            parts.append("✅ Recordatorios pendientes:\n\(reminders)")
        }

        let now = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        parts.insert("🕐 Fecha y hora actual: \(now)", at: 0)

        return parts.joined(separator: "\n\n")
    }
}
