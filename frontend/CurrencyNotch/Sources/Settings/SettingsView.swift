import CurrencyCore
import SwiftUI

/// Settings window: Currencies / Display / Alerts / General (SPEC F23). Changes apply instantly.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            CurrenciesTab(model: model)
                .tabItem { Label("Currencies", systemImage: "dollarsign.circle") }
            DisplayTab(model: model)
                .tabItem { Label("Display", systemImage: "paintpalette") }
            AlertsTab(model: model)
                .tabItem { Label("Alerts", systemImage: "bell") }
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 540, height: 500)
        .padding()
    }
}

// MARK: - Currencies

private struct CurrenciesTab: View {
    let model: AppModel
    @State private var query = ""
    @State private var kind: CatalogSearch.KindFilter = .all
    @State private var showingBasePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Base currency")
                Spacer()
                Button {
                    showingBasePicker = true
                } label: {
                    CurrencyLabel(model: model, code: model.watchList.baseCode)
                }
                .popover(isPresented: $showingBasePicker, arrowEdge: .bottom) {
                    BasePicker(model: model) { showingBasePicker = false }
                }
            }

            Text("Watch list").font(.headline)
            List {
                ForEach(model.watchList.orderedCodes, id: \.self) { code in
                    HStack {
                        CurrencyLabel(model: model, code: code)
                        Spacer()
                        Button {
                            model.apply(.removeCurrency(code))
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .disabled(model.watchList.orderedCodes.count <= 1)
                        .help(Text("Remove"))
                        .accessibilityLabel(Text("Remove"))
                    }
                }
                .onMove { source, destination in
                    model.apply(.moveCurrencies(source, destination))
                }
            }
            .frame(height: 170)

            HStack {
                TextField("Search currencies", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $kind) {
                    Text("All").tag(CatalogSearch.KindFilter.all)
                    Text("Fiat").tag(CatalogSearch.KindFilter.fiat)
                    Text("Crypto").tag(CatalogSearch.KindFilter.crypto)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            let results = CatalogSearch(locale: model.settings.language.formattingLocale)
                .search(query, kind: kind, excluding: Set(model.watchList.orderedCodes + [model.watchList.baseCode]))
            List(results) { currency in
                HStack {
                    CurrencyLabel(model: model, code: currency.code)
                    Spacer()
                    Button("Add") { model.apply(.addCurrency(currency.code)) }
                        .buttonStyle(.borderless)
                }
            }
            .overlay {
                if results.isEmpty { Text("No matches").foregroundStyle(.secondary) }
            }
        }
    }
}

private struct BasePicker: View {
    let model: AppModel
    let done: () -> Void
    @State private var query = ""

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search currencies", text: $query).textFieldStyle(.roundedBorder)
            let results = CatalogSearch(locale: model.settings.language.formattingLocale).search(query)
            List(results) { currency in
                Button {
                    model.apply(.setBase(currency.code))
                    done()
                } label: {
                    HStack {
                        CurrencyLabel(model: model, code: currency.code)
                        Spacer()
                        if currency.code == model.watchList.baseCode { Image(systemName: "checkmark") }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 320, height: 360)
    }
}

/// Icon + code + localized name. Codes stay LTR inside RTL text.
struct CurrencyLabel: View {
    let model: AppModel
    let code: String

    var body: some View {
        HStack(spacing: 8) {
            CurrencyIconView(icon: model.rowBuilder.icon(for: code), size: 18)
            Text(verbatim: code.ltrIsolated).font(.body.monospaced())
            Text(verbatim: model.localizedName(for: code)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

// MARK: - Display

private struct DisplayTab: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        Slider(value: Binding(get: { model.settings.rotationInterval },
                                              set: { model.apply(.setRotationInterval($0.rounded())) }),
                               in: AppSettings.rotationRange, step: 1)
                        Text("\(Int(model.settings.rotationInterval)) s")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                } label: {
                    Text("Rotation interval")
                }
                Picker("Change range", selection: Binding(get: { model.settings.changeRange },
                                                          set: { model.apply(.setChangeRange($0)) })) {
                    Text("24h").tag(ChangeRange.h24)
                    Text("7d").tag(ChangeRange.d7)
                    Text("30d").tag(ChangeRange.d30)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker("Theme", selection: Binding(get: { model.settings.themeID },
                                                   set: { model.apply(.setTheme($0)) })) {
                    ForEach(ThemeID.allCases, id: \.self) { theme in
                        Text(ThemeNames.name(theme)).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
                LabeledContent {
                    ThemePreview(model: model)
                } label: {
                    Text("Preview")
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Live preview of the selected theme on the collapsed pill, effects included.
private struct ThemePreview: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = model.theme(for: colorScheme == .dark ? .dark : .light)
        ZStack {
            PillSurface(size: PillLayout.collapsedSize)
            CollapsedBoardView(model: model)
        }
        .environment(\.pillTheme, theme)
        .environment(\.pillEffectsRunning, model.effectsRunning(for: theme))
    }
}

enum ThemeNames {
    static func name(_ theme: ThemeID) -> LocalizedStringKey {
        switch theme {
        case .ice: "Ice"
        case .fire: "Fire"
        case .israel: "Israel"
        case .classicNotch: "Classic Black Notch"
        case .frostedGlass: "Frosted Glass"
        }
    }
}

// MARK: - Alerts

// MARK: - General

private struct GeneralTab: View {
    let model: AppModel

    var body: some View {
        Form {
            Picker("Language", selection: Binding(get: { model.settings.language },
                                                  set: { model.apply(.setLanguage($0)) })) {
                Text("System").tag(AppLanguage.system)
                // Each language in its own name, so it can be found whatever the current language.
                Text(verbatim: "עברית").tag(AppLanguage.he)
                Text(verbatim: "English").tag(AppLanguage.en)
                Text(verbatim: "Español").tag(AppLanguage.es)
                Text(verbatim: "Русский").tag(AppLanguage.ru)
                Text(verbatim: "简体中文").tag(AppLanguage.zhHans)
            }
            if model.needsRestartForLanguage {
                HStack {
                    Text("Restart Currency Notch to switch language.").font(.callout)
                    Spacer()
                    Button("Restart Now") { LanguageOverride.relaunch() }
                }
            }
            Section {
                Toggle("Launch at login", isOn: Binding(get: { model.loginItemState.isOn },
                                                        set: { model.apply(.setLaunchAtLogin($0)) }))
                    .disabled(!model.loginItemState.isAvailable)
                if model.loginItemState.needsApproval {
                    HStack {
                        Text("macOS needs your approval to open Currency Notch at login.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items Settings") { MainAppLoginItem.openSystemSettings() }
                    }
                }
                Toggle("Pause effects on battery", isOn: Binding(get: { model.settings.pauseEffectsOnBattery },
                                                                 set: { model.apply(.setPauseEffectsOnBattery($0)) }))
            }
            Picker("Refresh interval", selection: Binding(get: { model.settings.refreshInterval },
                                                          set: { model.apply(.setRefreshInterval($0)) })) {
                ForEach(PreferencesEditor.refreshIntervalChoices, id: \.self) { seconds in
                    Text("\(Int(seconds / 60)) min").tag(seconds)
                }
            }
        }
        .formStyle(.grouped)
    }
}
