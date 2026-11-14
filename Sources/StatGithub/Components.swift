import SwiftUI
import Charts

// MARK: - Cartes

struct Card<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08)))
    }
}

struct KPI: View {
    let title: String
    let value: Int
    let icon: String
    let tint: Color
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(value.fr)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(sub ?? " ").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08)))
    }
}

// MARK: - Graphique : barres (total) + courbe (uniques) avec survol

struct TrafficChart: View {
    let points: [DayPoint]
    let total: KeyPath<DayPoint, Int>
    let unique: KeyPath<DayPoint, Int>
    let totalLabel: String
    let uniqueLabel: String
    let color: Color

    @State private var selected: Date?

    private var hovered: DayPoint? {
        guard let selected else { return nil }
        return points.min { abs($0.day.timeIntervalSince(selected)) < abs($1.day.timeIntervalSince(selected)) }
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                BarMark(x: .value("Jour", p.day, unit: .day), y: .value(totalLabel, p[keyPath: total]))
                    .foregroundStyle(by: .value("Série", totalLabel))
                LineMark(x: .value("Jour", p.day, unit: .day), y: .value(uniqueLabel, p[keyPath: unique]))
                    .foregroundStyle(by: .value("Série", uniqueLabel))
                    .interpolationMethod(.monotone)
            }
            if let h = hovered {
                RuleMark(x: .value("Jour", h.day, unit: .day))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.day.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR"))))
                                .font(.caption.bold())
                            Text("\(totalLabel) : \(h[keyPath: total].fr)").font(.caption)
                            Text("\(uniqueLabel) : \(h[keyPath: unique].fr)").font(.caption)
                        }
                        .padding(6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.15)))
                    }
            }
        }
        .chartForegroundStyleScale([totalLabel: color.opacity(0.35), uniqueLabel: color])
        .chartXSelection(value: $selected)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 210)
    }
}

// MARK: - Classements (sources de trafic, pages)

struct RankRow: Identifiable {
    var id: String
    var label: String
    var detail: String?
    var value: Int
    var secondary: Int
}

struct RankList: View {
    let rows: [RankRow]
    var tint: Color = .blue
    var valueLabel = "vues"
    var emptyText = "Aucune donnée pour le moment."

    var body: some View {
        if rows.isEmpty {
            Text(emptyText).font(.callout).foregroundStyle(.secondary)
        } else {
            let maxValue = Double(max(rows.map(\.value).max() ?? 1, 1))
            VStack(spacing: 6) {
                ForEach(rows) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.label).lineLimit(1).truncationMode(.middle)
                            if let d = r.detail {
                                Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Text("\(r.value.fr) \(valueLabel)").monospacedDigit()
                        Text("· \(r.secondary.fr) uniq.").foregroundStyle(.secondary).monospacedDigit()
                    }
                    .font(.callout)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(alignment: .leading) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(tint.opacity(0.12))
                                .frame(width: geo.size.width * CGFloat(Double(r.value) / maxValue))
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Commits par semaine

struct CommitsChart: View {
    let weeks: [WeekPoint]
    @State private var selected: Date?

    private var hovered: WeekPoint? {
        guard let selected else { return nil }
        return weeks.min { abs($0.day.timeIntervalSince(selected)) < abs($1.day.timeIntervalSince(selected)) }
    }

    var body: some View {
        Chart {
            ForEach(weeks) { w in
                BarMark(x: .value("Semaine", w.day, unit: .weekOfYear), y: .value("Commits", w.commits))
                    .foregroundStyle(Color.orange.opacity(0.75))
            }
            if let h = hovered {
                RuleMark(x: .value("Semaine", h.day, unit: .weekOfYear))
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Semaine du \(h.day.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR"))))")
                                .font(.caption.bold())
                            Text("\(h.commits.fr) commits").font(.caption)
                        }
                        .padding(6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.15)))
                    }
            }
        }
        .chartXSelection(value: $selected)
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 170)
    }
}
