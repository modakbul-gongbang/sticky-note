import AppKit
import StickyNotesCore

/// One day in the week strip or the month grid. It draws its own weekday, date number, and
/// task ring so the calendar stays a quiet field of text; only the selected day is filled.
/// The ring's accent arc is the share of the day's tasks that are done.
final class DayButton: NSButton {
    var weekdayText: String?
    var dayText = ""
    var isToday = false
    var isSelectedDay = false
    var isOutsideMonth = false
    var taskCount: TaskCount?
    var accentColor = NSColor.systemRed

    // NSButton draws in flipped coordinates: y grows downward from the top edge.
    override func draw(_ dirtyRect: NSRect) {
        if isSelectedDay {
            NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 9, yRadius: 9).fill()
        }
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        if let weekdayText {
            NSAttributedString(string: weekdayText, attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1),
                .paragraphStyle: centered,
            ]).draw(in: NSRect(x: 0, y: 3, width: bounds.width, height: 13))
        }
        // The date sits above its tally; a day without tasks keeps the number centred.
        let hasTally = (taskCount?.total ?? 0) > 0
        let top: CGFloat = weekdayText == nil ? 0 : 16
        let numberY = top + (bounds.height - top) / 2 - (hasTally ? 15 : 9)
        let dayColor: NSColor
        if isToday {
            dayColor = accentColor
        } else if isOutsideMonth {
            dayColor = NSColor(calibratedWhite: 0.3, alpha: 1)
        } else {
            dayColor = NSColor(calibratedWhite: isSelectedDay ? 0.96 : 0.66, alpha: 1)
        }
        NSAttributedString(string: dayText, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: isSelectedDay || isToday ? .semibold : .regular),
            .foregroundColor: dayColor,
            .paragraphStyle: centered,
        ]).draw(in: NSRect(x: 0, y: numberY, width: bounds.width, height: 18))
        drawTally(below: numberY + 18, centered: centered)
    }

    /// "done/total" under the date: the done count in accent, the total in grey, and the whole
    /// tally in accent once every task is checked. Text with content but no tasks gets a dot.
    private func drawTally(below y: CGFloat, centered: NSParagraphStyle) {
        guard let taskCount else { return }
        guard taskCount.total > 0 else {
            NSColor(calibratedWhite: 0.5, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX - 2, y: y + 2, width: 4, height: 4)).fill()
            return
        }
        let finished = taskCount.done == taskCount.total
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let grey = NSColor(calibratedWhite: 0.5, alpha: 1)
        let tally = NSMutableAttributedString(string: "\(taskCount.done)", attributes: [
            .font: font,
            .foregroundColor: taskCount.done > 0 ? accentColor : grey,
            .paragraphStyle: centered,
        ])
        tally.append(NSAttributedString(string: "/\(taskCount.total)", attributes: [
            .font: font,
            .foregroundColor: finished ? accentColor : grey,
            .paragraphStyle: centered,
        ]))
        tally.draw(in: NSRect(x: 0, y: y, width: bounds.width, height: 14))
    }

    func configure(day: Date, weekday: String?, selected: Date, today: Date, taskCount: TaskCount?, outsideMonth: Bool) {
        weekdayText = weekday
        dayText = String(Calendar.current.component(.day, from: day))
        isToday = DailyNote.dayKey(for: day) == DailyNote.dayKey(for: today)
        isSelectedDay = DailyNote.dayKey(for: day) == DailyNote.dayKey(for: selected)
        isOutsideMonth = outsideMonth
        self.taskCount = taskCount
        let title = DailyNote.title(for: day)
        let label = taskCount.map { $0.total > 0 ? "\(title), 할 일 \($0.total)개 중 \($0.done)개 완료" : title } ?? title
        setAccessibilityLabel(label)
        toolTip = label
        needsDisplay = true
    }
}

private func chevronButton(symbol: String, label: String, target: AnyObject, action: Selector) -> NSButton {
    let button = NSButton()
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
    button.imagePosition = .imageOnly
    button.isBordered = false
    button.contentTintColor = NSColor(calibratedWhite: 0.55, alpha: 1)
    button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    button.target = target
    button.action = action
    button.setAccessibilityLabel(label)
    button.toolTip = label
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
}

/// Monday-to-Sunday row above the day's page. Choosing a day, or stepping a week with the
/// arrows, reports the chosen date; the controller decides what that day shows.
final class WeekStripView: NSView {
    var onSelectDay: ((Date) -> Void)?
    var onShowMonth: (() -> Void)?
    private let dayButtons: [DayButton] = (0..<7).map { _ in DayButton(title: "", target: nil, action: nil) }
    private var days: [Date] = []
    private var selected = Date()

    init(accentColor: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let previous = chevronButton(symbol: "chevron.left", label: "지난주", target: self, action: #selector(showPreviousWeek))
        let next = chevronButton(symbol: "chevron.right", label: "다음 주", target: self, action: #selector(showNextWeek))
        let month = chevronButton(symbol: "chevron.compact.down", label: "월 달력 보기", target: self, action: #selector(showMonth))
        for button in [previous, next] { button.widthAnchor.constraint(equalToConstant: 30).isActive = true }
        for (index, button) in dayButtons.enumerated() {
            button.isBordered = false
            button.tag = index
            button.target = self
            button.action = #selector(selectDay(_:))
            button.accentColor = accentColor
            button.translatesAutoresizingMaskIntoConstraints = false
        }
        let row = NSStackView(views: [previous] + dayButtons + [next])
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 0
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        addSubview(month)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.heightAnchor.constraint(equalToConstant: 56),
            month.topAnchor.constraint(equalTo: row.bottomAnchor),
            month.centerXAnchor.constraint(equalTo: centerXAnchor),
            month.widthAnchor.constraint(equalToConstant: 120),
            month.heightAnchor.constraint(equalToConstant: 20),
            month.bottomAnchor.constraint(equalTo: bottomAnchor),
        ] + dayButtons.dropFirst().map { $0.widthAnchor.constraint(equalTo: dayButtons[0].widthAnchor) }
          + dayButtons.map { $0.heightAnchor.constraint(equalTo: row.heightAnchor) })
        setAccessibilityLabel("이번 주 날짜")
    }

    required init?(coder: NSCoder) { nil }

    func show(selected: Date, today: Date, taskCounts: [String: TaskCount]) {
        self.selected = selected
        days = DailyNote.week(containing: selected)
        let weekdayNames = ["월", "화", "수", "목", "금", "토", "일"]
        for (index, button) in dayButtons.enumerated() {
            button.configure(
                day: days[index],
                weekday: weekdayNames[index],
                selected: selected,
                today: today,
                taskCount: taskCounts[DailyNote.dayKey(for: days[index])],
                outsideMonth: false
            )
        }
    }

    @objc private func selectDay(_ sender: DayButton) {
        onSelectDay?(days[sender.tag])
    }

    @objc private func showPreviousWeek() { stepWeek(by: -7) }
    @objc private func showNextWeek() { stepWeek(by: 7) }
    @objc private func showMonth() { onShowMonth?() }

    private func stepWeek(by days: Int) {
        guard let target = Calendar.current.date(byAdding: .day, value: days, to: selected) else {
            preconditionFailure("Gregorian day arithmetic always succeeds")
        }
        onSelectDay?(target)
    }
}

/// The month grid that replaces the week and the page while it is open. The arrows page
/// through months without changing the selected day; choosing a day selects it and closes.
final class MonthCalendarView: NSView {
    var onSelectDay: ((Date) -> Void)?
    var onClose: (() -> Void)?
    private let titleLabel = NSTextField(labelWithString: "")
    private let dayButtons: [DayButton] = (0..<42).map { _ in DayButton(title: "", target: nil, action: nil) }
    private var days: [Date] = []
    private var displayedMonth = Date()
    private var selected = Date()
    private var today = Date()
    private var taskCounts: [String: TaskCount] = [:]

    init(accentColor: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel("월 달력")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.82, alpha: 1)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let previous = chevronButton(symbol: "chevron.left", label: "지난달", target: self, action: #selector(showPreviousMonth))
        let next = chevronButton(symbol: "chevron.right", label: "다음 달", target: self, action: #selector(showNextMonth))
        let close = chevronButton(symbol: "chevron.compact.up", label: "주 보기로 돌아가기", target: self, action: #selector(close))
        for button in [previous, next] {
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }
        let header = NSStackView(views: [previous, titleLabel, next])
        header.orientation = .horizontal
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false

        let weekdays = NSStackView(views: ["월", "화", "수", "목", "금", "토", "일"].map { name in
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textColor = NSColor(calibratedWhite: 0.42, alpha: 1)
            label.alignment = .center
            return label
        })
        weekdays.orientation = .horizontal
        weekdays.distribution = .fillEqually
        weekdays.translatesAutoresizingMaskIntoConstraints = false

        let rows = stride(from: 0, to: 42, by: 7).map { start -> NSStackView in
            let row = NSStackView(views: Array(dayButtons[start..<start + 7]))
            row.orientation = .horizontal
            row.distribution = .fillEqually
            row.spacing = 0
            return row
        }
        let grid = NSStackView(views: rows)
        grid.orientation = .vertical
        grid.distribution = .fillEqually
        grid.spacing = 0
        grid.translatesAutoresizingMaskIntoConstraints = false
        for (index, button) in dayButtons.enumerated() {
            button.isBordered = false
            button.tag = index
            button.target = self
            button.action = #selector(selectDay(_:))
            button.accentColor = accentColor
        }
        for subview in [header, close, weekdays, grid] { addSubview(subview) }
        NSLayoutConstraint.activate(rows.flatMap { row in
            [row.widthAnchor.constraint(equalTo: grid.widthAnchor)]
                + row.arrangedSubviews.map { $0.heightAnchor.constraint(equalTo: row.heightAnchor) }
        })
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            header.centerXAnchor.constraint(equalTo: centerXAnchor),
            header.heightAnchor.constraint(equalToConstant: 30),
            weekdays.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            weekdays.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            weekdays.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            weekdays.heightAnchor.constraint(equalToConstant: 14),
            grid.topAnchor.constraint(equalTo: weekdays.bottomAnchor, constant: 2),
            grid.leadingAnchor.constraint(equalTo: weekdays.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: weekdays.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: close.topAnchor),
            close.centerXAnchor.constraint(equalTo: centerXAnchor),
            close.widthAnchor.constraint(equalToConstant: 120),
            close.heightAnchor.constraint(equalToConstant: 20),
            close.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func show(selected: Date, today: Date, taskCounts: [String: TaskCount]) {
        self.selected = selected
        self.today = today
        self.taskCounts = taskCounts
        displayedMonth = selected
        render()
    }

    private func render() {
        let calendar = Calendar.current
        days = DailyNote.monthGrid(containing: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)
        titleLabel.stringValue = "\(calendar.component(.year, from: displayedMonth))년 \(month)월"
        for (index, button) in dayButtons.enumerated() {
            button.configure(
                day: days[index],
                weekday: nil,
                selected: selected,
                today: today,
                taskCount: taskCounts[DailyNote.dayKey(for: days[index])],
                outsideMonth: calendar.component(.month, from: days[index]) != month
            )
        }
    }

    @objc private func selectDay(_ sender: DayButton) { onSelectDay?(days[sender.tag]) }
    @objc private func close() { onClose?() }
    @objc private func showPreviousMonth() { stepMonth(by: -1) }
    @objc private func showNextMonth() { stepMonth(by: 1) }

    private func stepMonth(by months: Int) {
        guard let target = Calendar.current.date(byAdding: .month, value: months, to: displayedMonth) else {
            preconditionFailure("Gregorian month arithmetic always succeeds")
        }
        displayedMonth = target
        render()
    }
}
