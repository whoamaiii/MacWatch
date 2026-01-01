import Foundation

/// Date formatting utilities
public enum DateFormatters {
    /// Format for database date strings (YYYY-MM-DD)
    public static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Format for display (e.g., "Jan 15")
    public static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Format for display with year (e.g., "Jan 15, 2024")
    public static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// Format for time (e.g., "2:30 PM")
    public static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Format for hour (e.g., "2 PM")
    public static let hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }()

    /// Format for weekday (e.g., "Monday")
    public static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// Format for short weekday (e.g., "Mon")
    public static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

// MARK: - Duration Formatting

public extension Int {
    /// Format seconds as duration string (e.g., "2h 30m")
    var formattedDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    /// Format seconds as short duration (e.g., "2:30")
    var shortDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        }
        return "\(minutes)m"
    }

    /// Format large numbers with commas
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

public extension Double {
    /// Format as percentage (e.g., "85%")
    var percentageString: String {
        String(format: "%.0f%%", self)
    }

    /// Format as score with one decimal (e.g., "8.5")
    var scoreString: String {
        String(format: "%.1f", self)
    }
}

// MARK: - Date Extensions

public extension Date {
    /// Start of current day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of current day
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    }

    /// Start of current week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }

    /// Is this date today?
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Is this date yesterday?
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Days ago from now
    var daysAgo: Int {
        Calendar.current.dateComponents([.day], from: startOfDay, to: Date().startOfDay).day ?? 0
    }

    /// Human readable relative date
    var relativeString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if daysAgo < 7 {
            return DateFormatters.weekday.string(from: self)
        } else {
            return DateFormatters.shortDate.string(from: self)
        }
    }
}
