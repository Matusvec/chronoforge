import Foundation
import UserNotifications

/// Schedules local notifications for upcoming events and deadlines.
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleEventReminder(title: String, startDate: Date, minutesBefore: Int = 15) {
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: startDate.addingTimeInterval(-Double(minutesBefore * 60))
            ),
            repeats: false
        )

        let content = UNMutableNotificationContent()
        content.title = "Starting Soon"
        content.body = "\(title) begins in \(minutesBefore) minutes. Get moving."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "event-\(title)-\(startDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleCanvasDeadline(assignment: String, course: String, dueDate: Date) {
        let hoursBefore = [24, 2]
        for hours in hoursBefore {
            let triggerDate = dueDate.addingTimeInterval(-Double(hours * 3600))
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "📚 \(course)"
            content.body = "\(assignment) due in \(hours) hours. No excuses."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: triggerDate
                ),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "canvas-\(assignment)-\(hours)h",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func scheduleCheckInReminder(block: PlannedBlock, minutesAfterEnd: Int = 5) {
        let triggerDate = block.end.addingTimeInterval(Double(minutesAfterEnd * 60))
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Check-in"
        content.body = "What did you do for \(block.goalName)? Log it and stay honest."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            ),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "checkin-\(block.goalId)-\(block.start.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleBlockReminders(blocks: [PlannedBlock]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let upcoming = blocks.filter { $0.start > Date() && !$0.isFixed }
        for block in upcoming.prefix(50) {
            scheduleEventReminder(title: block.goalName, startDate: block.start)
            scheduleCheckInReminder(block: block)
        }
    }

    func scheduleDueDateReminders(tasks: [CanvasTask]) {
        for task in tasks {
            guard let due = task.dueAt else { continue }
            scheduleCanvasDeadline(
                assignment: task.assignmentName,
                course: task.courseName,
                dueDate: due
            )
        }
    }
}
