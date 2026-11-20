import CurrencyCore
import SwiftUI

/// Alerts tab (SPEC F23, F28–F29): list, add, edit, delete.
struct AlertsTab: View {
    let model: AppModel
    @State private var editing: AlertDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.notificationStatus == .denied {
                HStack {
                    Image(systemName: "bell.slash").foregroundStyle(.orange)
                    Text("Notifications are turned off for CurrenSee, so alerts can't notify you.")
                        .font(.callout)
                    Spacer()
                    Button("Open Notification Settings") { Notifier.openSystemSettings() }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
            }

            if model.alerts.isEmpty {
                ContentUnavailableView {
                    Label("No alerts yet", systemImage: "bell.badge")
                } description: {
                    Text("Get one notification when a rate crosses a threshold you choose.")
                }
            } else {
                List {
                    ForEach(model.alerts) { alert in
                        AlertRow(model: model, alert: alert)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editing = AlertDraft(alert: alert) }
                            .contextMenu {
                                Button("Edit") { editing = AlertDraft(alert: alert) }
                                Button("Delete", role: .destructive) { model.apply(.deleteAlert(id: alert.id)) }
                            }
                    }
                }
            }

            HStack {
                Button {
                    editing = AlertDraft(model: model)
                } label: {
                    Label("Add Alert", systemImage: "plus")
                }
                Spacer()
                if !model.alerts.isEmpty {
                    Text("Double-click an alert to edit it.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $editing) { draft in
            AlertEditor(model: model, draft: draft) { editing = nil }
        }
        .onAppear { model.reloadNotificationStatus() }
    }
}

private struct AlertRow: View {
    let model: AppModel
    let alert: RateAlert

    var body: some View {
        HStack(spacing: 10) {
            CurrencyIconView(icon: model.rowBuilder.icon(for: alert.quoteCode), size: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: alert.quoteCode.ltrIsolated).font(.body.monospaced())
                    Text(alert.direction == .above ? "▲ above" : "▼ below")
                    Text(verbatim: AlertMessage.make(for: alert, formatter: model.formatter).threshold.ltrIsolated)
                        .monospacedDigit()
                }
                status.font(.caption)
            }
            Spacer()
            Button {
                model.apply(.deleteAlert(id: alert.id))
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(Text("Delete"))
            .accessibilityLabel(Text("Delete"))
        }
    }

    @ViewBuilder
    private var status: some View {
        switch model.activity(of: alert) {
        case .wrongBase(let base):
            Text("Inactive: set in \(base), but the base is now \(model.watchList.baseCode).")
                .foregroundStyle(.orange)
        case .notWatched(let code):
            Text("Inactive: \(code) is no longer in your watch list.").foregroundStyle(.orange)
        case .active:
            if alert.isArmed {
                Text("Waiting").foregroundStyle(.secondary)
            } else if alert.lastTriggeredAt != nil {
                Text("Triggered — re-arms when the rate crosses back.").foregroundStyle(.secondary)
            } else if alert.direction == .above {
                Text("Already above — will notify on the next crossing.").foregroundStyle(.secondary)
            } else {
                Text("Already below — will notify on the next crossing.").foregroundStyle(.secondary)
            }
        }
    }
}

/// Editable copy of an alert (new or existing).
struct AlertDraft: Identifiable {
    let id: UUID
    let existingID: UUID?
    var quoteCode: String
    var direction: AlertDirection
    var threshold: Decimal

    init(alert: RateAlert) {
        id = UUID()
        existingID = alert.id
        quoteCode = alert.quoteCode
        direction = alert.direction
        threshold = alert.threshold
    }

    @MainActor
    init(model: AppModel) {
        id = UUID()
        existingID = nil
        quoteCode = model.currentCode ?? model.watchList.orderedCodes.first ?? "USD"
        direction = .above
        threshold = model.snapshot.quotes[quoteCode]?.value ?? 1
    }
}

private struct AlertEditor: View {
    let model: AppModel
    @State var draft: AlertDraft
    let done: () -> Void

    var body: some View {
        let current = model.snapshot.quotes[draft.quoteCode]?.value
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.existingID == nil ? "New Alert" : "Edit Alert").font(.headline)
            Form {
                Picker("Currency", selection: $draft.quoteCode) {
                    ForEach(model.watchList.orderedCodes, id: \.self) { code in
                        Text(verbatim: "\(code.ltrIsolated) — \(model.localizedName(for: code))").tag(code)
                    }
                }
                Picker("Notify when the rate is", selection: $draft.direction) {
                    Text("Above").tag(AlertDirection.above)
                    Text("Below").tag(AlertDirection.below)
                }
                .pickerStyle(.segmented)
                LabeledContent {
                    HStack {
                        TextField("", value: $draft.threshold,
                                  format: .number.precision(.fractionLength(0...8)).locale(model.settings.language.formattingLocale))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .leftToRight)
                        Text(verbatim: model.formatter.symbol(for: model.watchList.baseCode))
                    }
                } label: {
                    Text("Threshold")
                }
                if let current {
                    LabeledContent {
                        Text(verbatim: "\(model.formatter.number(current, quoteCode: draft.quoteCode)) \(model.formatter.symbol(for: model.watchList.baseCode))".ltrIsolated)
                            .monospacedDigit()
                    } label: {
                        Text("Current rate")
                    }
                }
            }
            .formStyle(.grouped)
            if let error = model.lastError {
                Text(verbatim: error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: done).keyboardShortcut(.cancelAction)
                Button("Save") {
                    let change: PreferenceChange = if let id = draft.existingID {
                        .updateAlert(id: id, quoteCode: draft.quoteCode, direction: draft.direction,
                                     threshold: draft.threshold, current: current)
                    } else {
                        .addAlert(quoteCode: draft.quoteCode, direction: draft.direction,
                                  threshold: draft.threshold, current: current)
                    }
                    if model.apply(change) { done() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
