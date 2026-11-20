import CurrencyCore
import SwiftUI

/// Dynamic-Island-style list of every watched rate (SPEC F13). Scrolls past 10 rows.
struct DropdownView: View {
    let model: AppModel

    var body: some View {
        let rows = model.rows
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        DropdownRow(row: row).frame(height: PillLayout.rowHeight)
                    }
                }
            }
            .scrollIndicators(rows.count > PillLayout.maxVisibleRows ? .automatic : .never)
            if let freshness = model.freshnessText {
                Text(freshness)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.orange)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, PillLayout.listPadding / 2)
        .padding(.horizontal, 12)
        .frame(width: PillLayout.expandedSize.width, height: model.listHeight)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black))
    }
}

private struct DropdownRow: View {
    let row: RateRow

    var body: some View {
        HStack(spacing: 8) {
            CurrencyIconView(icon: row.icon, size: 18)
            Text(verbatim: row.code)
                .frame(width: 42, alignment: .leading)
            Spacer(minLength: 4)
            Text(verbatim: "\(row.valueText) \(row.symbol)")
            Group {
                if let change = row.change.text {
                    Text(verbatim: "\(row.change.arrow)\(change)").foregroundStyle(ChangeColor.color(row.change.direction))
                } else {
                    Text(verbatim: "—").foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .frame(width: 66, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}
