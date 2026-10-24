import SwiftUI

/// Perfil (iPhone sheet from the avatar) and Ajustes (Mac `Settings` scene, ⌘,).
struct ProfileView: View {
    enum Presentation {
        case sheet
        case settings
    }

    @State private var viewModel: ProfileViewModel
    let presentation: Presentation
    @State private var confirmsLogout = false
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(AppLifecycleCoordinator.self) private var coordinator: AppLifecycleCoordinator?

    init(viewModel: ProfileViewModel, presentation: Presentation) {
        _viewModel = State(initialValue: viewModel)
        self.presentation = presentation
    }

    var body: some View {
        Form {
            ProfileHeaderSection(household: viewModel.household)

            Section {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    DatePicker(
                        selection: $viewModel.form.slotTimes[slot].date,
                        displayedComponents: .hourAndMinute
                    ) {
                        Text(slot.titleKey)
                    }
                }
                Picker("profile.shopping-day", selection: $viewModel.form.shoppingWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(verbatim: weekdayName(weekday).capitalizedFirst).tag(weekday)
                    }
                }
                .accessibilityIdentifier("profile-shopping-day")
                if viewModel.hasUnsavedSettings || viewModel.settingsState == .saving {
                    Button {
                        Task { await viewModel.send(.saveSettings) }
                    } label: {
                        if viewModel.settingsState == .saving {
                            ProgressView()
                        } else {
                            Text("profile.settings.save")
                        }
                    }
                    .accessibilityIdentifier("profile-save-settings")
                }
            } header: {
                Text("profile.meal-times")
            } footer: {
                Text("profile.meal-times.footer")
            }

            Section {
                Picker("profile.appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("profile-appearance")
            } header: {
                Text("profile.appearance")
            }

            Section {
                Toggle(
                    "profile.lock",
                    isOn: Binding(
                        get: { viewModel.lockPolicy.isEnabled },
                        set: { value in Task { await viewModel.send(.setLockEnabled(value)) } }
                    )
                )
                .accessibilityIdentifier("profile-lock")
                if viewModel.lockPolicy.isEnabled {
                    Picker(
                        "profile.lock.timeout",
                        selection: Binding(
                            get: { viewModel.lockPolicy.backgroundTimeout },
                            set: { value in Task { await viewModel.send(.setLockTimeout(value)) } }
                        )
                    ) {
                        ForEach(ProfileViewModel.lockTimeouts, id: \.self) { timeout in
                            Text(timeoutKey(timeout)).tag(timeout)
                        }
                    }
                }
            } header: {
                Text("profile.security")
            } footer: {
                Text("profile.lock.footer")
            }

            Section {
                LabeledContent("profile.sync.status") {
                    Text(syncStatusKey)
                }
                if let lastSync = viewModel.syncStatus.lastSyncAt {
                    LabeledContent("profile.sync.last") {
                        Text(lastSync, format: .relative(presentation: .named))
                    }
                }
                Button {
                    Task { await viewModel.send(.syncNow) }
                } label: {
                    HStack {
                        Text("profile.sync.now")
                        if viewModel.syncState == .syncing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.syncState == .syncing)
                .accessibilityIdentifier("profile-sync-now")
            } header: {
                Text("profile.sync")
            } footer: {
                Text("profile.sync.force-quit-note")
            }

            Section {
                Button(role: .destructive) {
                    confirmsLogout = true
                } label: {
                    HStack {
                        Text("profile.logout")
                        if viewModel.state == .loggingOut {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.state != .idle)
                .accessibilityIdentifier("profile-logout")
            } footer: {
                Text("profile.logout.footer")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(KodaColor.background)
        .navigationTitle(Text("profile.title"))
        .platformInlineNavigationTitle()
        .toolbar {
            if presentation == .sheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .confirmationDialog("profile.logout.confirm.title", isPresented: $confirmsLogout, titleVisibility: .visible) {
            Button("profile.logout", role: .destructive) {
                Task { await viewModel.send(.logout) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("profile.logout.confirm.message")
        }
        .toast($viewModel.toast)
        .task { await viewModel.send(.appeared) }
        .onChange(of: viewModel.state) {
            guard viewModel.state == .loggedOut else { return }
            if presentation == .sheet { dismiss() }
            coordinator?.didSignOut()
        }
    }

    private func weekdayName(_ isoWeekday: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.standaloneWeekdaySymbols[isoWeekday % 7]
    }

    private func timeoutKey(_ timeout: TimeInterval) -> LocalizedStringKey {
        timeout == 0 ? "profile.lock.timeout.immediately" : "profile.lock.timeout.minutes \(Int(timeout / 60))"
    }

    private var syncStatusKey: LocalizedStringKey {
        let status = viewModel.syncStatus
        if !status.isOnline {
            return status.pendingChanges == 0 ? "sync.offline" : "sync.offline.pending \(status.pendingChanges)"
        }
        if status.isSyncing { return "sync.syncing" }
        return status.pendingChanges > 0 ? "sync.pending \(status.pendingChanges)" : "sync.synced"
    }
}

/// Name, household and members.
private struct ProfileHeaderSection: View {
    let household: HouseholdContext?

    var body: some View {
        Section {
            HStack(spacing: KodaSpacing.s) {
                Text(verbatim: household?.avatarEmoji ?? String((household?.displayName ?? "K").prefix(1)).uppercased())
                    .font(KodaTypography.title)
                    .foregroundStyle(KodaColor.cream)
                    .frame(width: 56, height: 56)
                    .background(KodaColor.brand, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: household?.displayName ?? "")
                        .font(KodaTypography.headline)
                    Text(verbatim: household?.household.name ?? "")
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                }
            }
            .padding(.vertical, KodaSpacing.xxs)
            ForEach(household?.household.members ?? []) { member in
                HStack {
                    Text(verbatim: [member.avatarEmoji, member.displayName].compactMap { $0 }.joined(separator: " "))
                    Spacer()
                    Text(member.role == .owner ? "profile.member.owner" : "profile.member.member")
                        .font(KodaTypography.footnote)
                        .foregroundStyle(KodaColor.textSecondary)
                }
            }
        } header: {
            Text("profile.household")
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Profile · iPhone") {
        NavigationStack {
            ProfileView(viewModel: ProfilePreviewFactory.makeProfileViewModel(), presentation: .sheet)
        }
        .kodaPreview()
    }

    #Preview("Profile · dark") {
        NavigationStack {
            ProfileView(viewModel: ProfilePreviewFactory.makeProfileViewModel(), presentation: .sheet)
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Profile · Mac", traits: .fixedLayout(width: 560, height: 700)) {
        ProfileView(viewModel: ProfilePreviewFactory.makeProfileViewModel(), presentation: .settings)
            .kodaPreview()
    }
#endif
