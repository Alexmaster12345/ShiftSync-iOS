import SwiftUI
import UIKit

// MARK: - Export Range

enum ExportRange: String, CaseIterable {
    case thisMonth  = "This Month"
    case lastMonth  = "Last Month"
    case thisYear   = "This Year"
    case allTime    = "All Time"

    func dates() -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end   = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, end)
        case .lastMonth:
            let thisStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -1, to: thisStart)!
            let end   = cal.date(byAdding: .day, value: -1, to: thisStart)!
            return (start, end)
        case .thisYear:
            let start = cal.date(from: cal.dateComponents([.year], from: now))!
            let end   = cal.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
            return (start, end)
        case .allTime:
            return (Date.distantPast, Date.distantFuture)
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    @ObservedObject var store: ShiftStore
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRange: ExportRange = .thisMonth
    @State private var isExporting = false

    private var filteredEntries: [ShiftEntry] {
        let (start, end) = selectedRange.dates()
        return store.entries
            .filter { $0.startedAt >= start && $0.startedAt <= end }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var totalHours: Double   { filteredEntries.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 } }
    private var totalEarnings: Double { filteredEntries.reduce(0) { $0 + $1.estimatedPay } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                navHeader(title: "Export Reports", dismiss: dismiss)

                // Range picker card — label on top, dropdown centered below
                VStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(.tealAccent)
                        Text("Period")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.ssTextMuted)
                            .kerning(0.4)
                    }
                    Picker("", selection: $selectedRange) {
                        ForEach(ExportRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.tealAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.darkBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Summary card
                VStack(spacing: 12) {
                    HStack {
                        Text("SUMMARY").font(.system(size: 11, weight: .bold)).foregroundColor(.ssTextMuted).kerning(0.5)
                        Spacer()
                        Text("\(filteredEntries.count) shifts").font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                    }
                    HStack(spacing: 0) {
                        summaryCell(label: "Total Hours", value: String(format: "%.1fh", totalHours), color: .shiftBlue)
                        Divider().frame(height: 40)
                        summaryCell(label: "Total Pay", value: "\(settings.currency.symbol)\(String(format: "%.2f", totalEarnings))", color: .greenAccent)
                    }
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Export buttons
                VStack(spacing: 10) {
                    exportButton(
                        icon: "doc.text.fill",
                        label: "Export as CSV",
                        subtitle: "Open in Numbers, Excel, or any spreadsheet app",
                        color: .greenAccent
                    ) { exportCSV() }

                    exportButton(
                        icon: "doc.richtext.fill",
                        label: "Export as PDF",
                        subtitle: "Formatted report for payslips or records",
                        color: .shiftBlue
                    ) { exportPDF() }
                }

                // Preview list
                if !filteredEntries.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("PREVIEW").font(.system(size: 11, weight: .bold)).foregroundColor(.ssTextMuted).kerning(0.5)
                            Spacer()
                        }
                        .padding(.bottom, 8)

                        VStack(spacing: 8) {
                            ForEach(filteredEntries.prefix(10)) { entry in
                                previewRow(entry)
                            }
                            if filteredEntries.count > 10 {
                                Text("+ \(filteredEntries.count - 10) more shifts")
                                    .font(.system(size: 12)).foregroundColor(.ssTextMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 4)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "tray").font(.system(size: 34)).foregroundColor(.ssTextMuted)
                        Text("No shifts in this period").font(.system(size: 14)).foregroundColor(.ssTextMuted)
                    }
                    .frame(maxWidth: .infinity).padding(32)
                    .background(Color.darkCard).clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Subviews

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .black)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(.ssTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }

    private func exportButton(icon: String, label: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 15, weight: .semibold)).foregroundColor(.ssTextPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward").font(.system(size: 13, weight: .semibold)).foregroundColor(color)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(filteredEntries.isEmpty)
        .opacity(filteredEntries.isEmpty ? 0.4 : 1)
    }

    private func previewRow(_ entry: ShiftEntry) -> some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let endDate = entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60)
        return HStack(spacing: 10) {
            Text(fmt.string(from: entry.startedAt))
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextSecondary)
                .frame(width: 48, alignment: .leading)
            Text(entry.shiftType.label)
                .font(.system(size: 12)).foregroundColor(.ssTextPrimary)
            Spacer()
            if entry.shiftType.isDayType {
                Text("1 day").font(.system(size: 12)).foregroundColor(.ssTextSecondary)
            } else {
                Text("\(timeFmt.string(from: entry.startedAt))–\(timeFmt.string(from: endDate))")
                    .font(.system(size: 12)).foregroundColor(.ssTextSecondary)
            }
            Text("\(settings.currency.symbol)\(String(format: "%.2f", entry.estimatedPay))")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.greenAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - CSV Export

    private func exportCSV() {
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        var csv = "Date,Type,Start,End,Duration (h),Pay (\(settings.currency.rawValue))\n"
        for e in filteredEntries {
            let endDate = e.startedAt.addingTimeInterval(Double(e.durationMinutes) * 60)
            let hours   = String(format: "%.2f", Double(e.durationMinutes) / 60.0)
            let pay     = String(format: "%.2f", e.estimatedPay)
            if e.shiftType.isDayType {
                csv += "\(dateFmt.string(from: e.startedAt)),\(e.shiftType.label),,,1.0,\(pay)\n"
            } else {
                csv += "\(dateFmt.string(from: e.startedAt)),\(e.shiftType.label),\(timeFmt.string(from: e.startedAt)),\(timeFmt.string(from: endDate)),\(hours),\(pay)\n"
            }
        }
        share(data: Data(csv.utf8), filename: "ShiftSync-\(selectedRange.rawValue.replacingOccurrences(of: " ", with: "-")).csv")
    }

    // MARK: - PDF Export

    private func exportPDF() {
        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "d MMM yyyy"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        let (rangeStart, rangeEnd) = selectedRange.dates()
        let rangeLabel = selectedRange == .allTime
            ? "All Time"
            : "\(dateFmt.string(from: rangeStart)) – \(dateFmt.string(from: rangeEnd))"

        let data = renderer.pdfData { ctx in
            var y: CGFloat = margin
            let pageEntries = filteredEntries

            func newPage() {
                ctx.beginPage()
                y = margin
            }

            func checkPageBreak(needed: CGFloat) {
                if y + needed > pageH - margin { newPage() }
            }

            func drawText(_ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor = .black, maxWidth: CGFloat = pageW) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                text.draw(in: CGRect(x: x, y: y, width: maxWidth - x, height: 200), withAttributes: attrs)
            }

            newPage()

            // Header bar
            UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: pageW - margin*2, height: 50), cornerRadius: 8).fill()
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "ShiftSync — Shift Report".draw(at: CGPoint(x: margin + 16, y: y + 14), withAttributes: headerAttrs)
            y += 64

            // Period + generated
            drawText("Period: \(rangeLabel)", x: margin, y: y, font: .systemFont(ofSize: 11), color: .darkGray)
            let generatedStr = "Generated: \(dateFmt.string(from: Date()))"
            let genSize = (generatedStr as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
            drawText(generatedStr, x: pageW - margin - genSize.width, y: y, font: .systemFont(ofSize: 11), color: .darkGray)
            y += 20

            // Divider
            UIColor.lightGray.setStroke()
            let divPath = UIBezierPath(); divPath.move(to: CGPoint(x: margin, y: y)); divPath.addLine(to: CGPoint(x: pageW - margin, y: y))
            divPath.lineWidth = 0.5; divPath.stroke(); y += 16

            // Summary
            drawText("SUMMARY", x: margin, y: y, font: .systemFont(ofSize: 9, weight: .bold), color: .gray)
            y += 16
            let summaryItems = [
                ("Total Shifts", "\(filteredEntries.count)"),
                ("Total Hours", String(format: "%.1f h", totalHours)),
                ("Total Pay", "\(settings.currency.symbol)\(String(format: "%.2f", totalEarnings))")
            ]
            let colW = (pageW - margin * 2) / CGFloat(summaryItems.count)
            for (i, (label, value)) in summaryItems.enumerated() {
                let x = margin + CGFloat(i) * colW
                drawText(value, x: x, y: y, font: .systemFont(ofSize: 16, weight: .bold), color: .black)
                drawText(label, x: x, y: y + 20, font: .systemFont(ofSize: 10), color: .darkGray)
            }
            y += 46

            // Divider
            divPath.removeAllPoints(); divPath.move(to: CGPoint(x: margin, y: y)); divPath.addLine(to: CGPoint(x: pageW - margin, y: y))
            divPath.stroke(); y += 14

            // Table header
            let cols: [(String, CGFloat)] = [("Date", 70), ("Type", 80), ("Start", 50), ("End", 50), ("Hours", 50), ("Pay", 70)]
            var x: CGFloat = margin
            let headerFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
            UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y - 4, width: pageW - margin*2, height: 22), cornerRadius: 4).fill()
            for (col, w) in cols {
                drawText(col.uppercased(), x: x + 4, y: y, font: headerFont, color: .darkGray)
                x += w
            }
            y += 22

            // Table rows
            let rowFont  = UIFont.systemFont(ofSize: 10)
            let boldFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
            for (idx, entry) in pageEntries.enumerated() {
                checkPageBreak(needed: 22)
                if idx % 2 == 0 {
                    UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1).setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: pageW - margin*2, height: 20)).fill()
                }
                let endDate = entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60)
                let rowValues: [String] = [
                    dateFmt.string(from: entry.startedAt),
                    entry.shiftType.label,
                    entry.shiftType.isDayType ? "—" : timeFmt.string(from: entry.startedAt),
                    entry.shiftType.isDayType ? "—" : timeFmt.string(from: endDate),
                    entry.shiftType.isDayType ? "1 day" : String(format: "%.1fh", Double(entry.durationMinutes) / 60.0),
                    "\(settings.currency.symbol)\(String(format: "%.2f", entry.estimatedPay))"
                ]
                x = margin
                for (i, (_, w)) in cols.enumerated() {
                    let font = i == 5 ? boldFont : rowFont
                    drawText(rowValues[i], x: x + 4, y: y + 4, font: font)
                    x += w
                }
                y += 20
            }

            // Footer
            y = pageH - margin
            UIColor.lightGray.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: y - 12, width: pageW - margin*2, height: 0.5)).fill()
            drawText("ShiftSync — Confidential", x: margin, y: y - 8, font: .systemFont(ofSize: 9), color: .lightGray)
        }

        share(data: data, filename: "ShiftSync-Report-\(selectedRange.rawValue.replacingOccurrences(of: " ", with: "-")).pdf")
    }

    // MARK: - Share

    private func share(data: Data, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}
