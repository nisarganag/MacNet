import AppKit
import MacNetCore
import SwiftUI

struct SettingsPage: View {
    @Bindable var preferences: Preferences
    let loginItem: LoginItem
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Back")
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    startAtLogin
                    display
                    about
                }
            }
            Spacer(minLength: 0)
        }
        .onAppear { loginItem.refresh() }
    }

    private var startAtLogin: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at login")
                        .font(.system(size: 13, weight: .medium))
                    Text("Open MacNet automatically when you log in.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            if let status = loginItem.statusText {
                HStack(alignment: .firstTextBaseline) {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if loginItem.needsApproval {
                        Spacer()
                        Button("Open Login Items") { loginItem.openSystemSettings() }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
            }
        }
        .glassCard()
    }

    private var display: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("Update every") {
                Picker("Update every", selection: $preferences.updateInterval) {
                    ForEach(Preferences.intervals, id: \.self) { Text("\(Int($0)) s").tag($0) }
                }
            }
            row("Show speeds in") {
                Picker("Show speeds in", selection: $preferences.unitStyle) {
                    Text("Bytes").tag(UnitStyle.bytes)
                    Text("Bits").tag(UnitStyle.bits)
                }
            }
            row("Glass") {
                Picker("Glass", selection: $preferences.glassStyle) {
                    Text("Frosted").tag(GlassStyle.regular)
                    Text("Clear").tag(GlassStyle.clear)
                }
            }
        }
        .glassCard()
    }

    private var about: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("MacNet")
                    .font(.system(size: 13, weight: .semibold))
                Text(AppInfo.versionDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Link("Release notes", destination: AppInfo.releases)
                .font(.system(size: 12))
        }
        .glassCard()
    }

    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            control()
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
        }
    }
}
