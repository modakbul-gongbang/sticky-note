import AppKit
import StickyNotesCore

/// One day of the week strip. It draws its own weekday, date number, and content dot so the
/// row stays a quiet line of text; only the selected day gets a filled background.
final class DayButton: NSButton {
    var weekdayText = ""
    var dayText = ""
    var isToday = false
    var isSelectedDay = false
    var hasContent = false
    var accentColor = NSColor.systemRed

    override func draw(_ dirtyRect: NSRect) {
        if isSelectedDay {
            NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 9, yRadius: 9).fill()
        }
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let weekday = NSAttributedString(string: weekdayText, attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1),
            .paragraphStyle: centered,
        ])
        let dayColor: NSColor = isToday
            ? accentColor
            : NSColor(calibratedWhite: isSelectedDay ? 0.96 : 0.66, alpha: 1)
        let day = NSAttributedString(string: dayText, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: isSelectedDay || isToday ? .semibold : .regular),
            .foregroundColor: dayColor,
            .paragraphStyle: centered,
        ])
        // NSButton draws in flipped coordinates: y grows downward from the top edge.
        weekday.draw(in: NSRect(x: 0, y: 4, width: bounds.width, height: 14))
        day.draw(in: NSRect(x: 0, y: 18, width: bounds.width, height: 19))
        if hasContent {
            NSColor(calibratedWhite: 0.5, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX - 2, y: bounds.height - 7, width: 4, height: 4)).fill()
        }
    }
}

/// Monday-to-Sunday row above today's page. Choosing a day, or stepping a week with the
/// arrows, reports the chosen date; the controller decides what that day shows.
final class WeekStripView: NSView {
    var onSelectDay: ((Date) -> Void)?
    private let dayButtons: [DayButton] = (0..<7).map { _ in DayButton(title: "", target: nil, action: nil) }
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private var days: [Date] = []
    private var selected = Date()

    init(accentColor: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for (button, symbol, label, action) in [
            (previousButton, "chevron.left", "지난주", #selector(showPreviousWeek)),
            (nextButton, "chevron.right", "다음 주", #selector(showNextWeek)),
        ] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.contentTintColor = NSColor(calibratedWhite: 0.45, alpha: 1)
            button.target = self
            button.action = action
            button.setAccessibilityLabel(label)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 18).isActive = true
        }
        for (index, button) in dayButtons.enumerated() {
            button.isBordered = false
            button.tag = index
            button.target = self
            button.action = #selector(selectDay(_:))
            button.accentColor = accentColor
            button.translatesAutoresizingMaskIntoConstraints = false
        }
        let stack = NSStackView(views: [previousButton] + dayButtons + [nextButton])
        stack.orientation = .horizontal
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: 46),
        ] + dayButtons.dropFirst().map { $0.widthAnchor.constraint(equalTo: dayButtons[0].widthAnchor) }
          + dayButtons.map { $0.heightAnchor.constraint(equalTo: stack.heightAnchor) })
        setAccessibilityLabel("이번 주 날짜")
    }

    required init?(coder: NSCoder) { nil }

    func show(selected: Date, today: Date, daysWithContent: Set<String>) {
        self.selected = selected
        days = DailyNote.week(containing: selected)
        let todayKey = DailyNote.dayKey(for: today)
        let selectedKey = DailyNote.dayKey(for: selected)
        let weekdayNames = ["월", "화", "수", "목", "금", "토", "일"]
        for (index, button) in dayButtons.enumerated() {
            let key = DailyNote.dayKey(for: days[index])
            button.weekdayText = weekdayNames[index]
            button.dayText = String(Calendar.current.component(.day, from: days[index]))
            button.isToday = key == todayKey
            button.isSelectedDay = key == selectedKey
            button.hasContent = daysWithContent.contains(key)
            let title = DailyNote.title(for: days[index])
            button.setAccessibilityLabel(title)
            button.toolTip = title
            button.needsDisplay = true
        }
    }

    @objc private func selectDay(_ sender: DayButton) {
        onSelectDay?(days[sender.tag])
    }

    @objc private func showPreviousWeek() { stepWeek(by: -7) }
    @objc private func showNextWeek() { stepWeek(by: 7) }

    private func stepWeek(by days: Int) {
        guard let target = Calendar.current.date(byAdding: .day, value: days, to: selected) else {
            preconditionFailure("Gregorian day arithmetic always succeeds")
        }
        onSelectDay?(target)
    }
}
