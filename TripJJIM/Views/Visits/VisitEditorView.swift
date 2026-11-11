import SwiftUI

struct VisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TripStore.self) private var store
    @State private var visit: Visit
    @State private var isRequestingPermission = false
    @State private var reminderMessage: String?
    @State private var memo: String

    private let region: String?
    private let tripRegionLocation: TripRegionLocation?
    private let original: Visit
    private let isNew: Bool
    private let onSave: (Visit) -> Bool

    init(visit: Visit, isNew: Bool, region: String?, tripRegionLocation: TripRegionLocation? = nil, onSave: @escaping (Visit) -> Bool) {
        _visit = State(initialValue: visit)
        _memo = State(initialValue: visit.memo ?? "")
        self.region = region
        self.tripRegionLocation = tripRegionLocation
        original = visit
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("장소와 시간") {
                    TextField("장소 이름", text: $visit.placeName)
                        .accessibilityIdentifier("place-name")
                    if let address = visit.address {
                        Label(address, systemImage: "mappin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        PlaceSearchView(region: region, tripRegionLocation: tripRegionLocation) { place in
                            visit.placeName = place.name
                            visit.coordinate = place.coordinate
                            visit.address = place.address
                        }
                    } label: {
                        Label(isNew ? "장소 검색" : "장소 변경", systemImage: "magnifyingglass")
                    }
                    DatePicker("방문 날짜", selection: $visit.visitDate, displayedComponents: .date)
                        .accessibilityIdentifier("visit-date")
                    DatePicker("방문 시간", selection: $visit.visitDate, displayedComponents: .hourAndMinute)
                }
                Section("방문 메모") {
                    TextField("메모를 입력해 주세요", text: $memo, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("visit-memo")
                }
                reminderSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "방문 일정 추가" : "방문 일정 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(cleanName.isEmpty || isRequestingPermission)
                }
            }
            .interactiveDismissDisabled(isRequestingPermission)
            .alert("방문 알림", isPresented: Binding(
                get: { reminderMessage != nil },
                set: { if !$0 { reminderMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(reminderMessage ?? "")
            }
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("방문 알림", isOn: Binding(
                get: { visit.reminderEnabled },
                set: setReminderEnabled
            ))
            .accessibilityIdentifier("visit-reminder")
            .disabled(isRequestingPermission)

            if visit.reminderEnabled {
                Picker("알림 시점", selection: $visit.selectedReminderPreset) {
                    ForEach(ReminderPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("reminder-preset")
                .accessibilityValue(visit.selectedReminderPreset.title)

                if visit.selectedReminderPreset == .custom {
                    let date = Binding(
                        get: { visit.reminderDate },
                        set: { visit.customReminderDate = $0 }
                    )
                    DatePicker("알림 날짜", selection: date, displayedComponents: .date)
                        .accessibilityIdentifier("reminder-date")
                    DatePicker("알림 시간", selection: date, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("reminder-time")
                }

                LabeledContent("알림 예정", value: "\(visit.reminderDate.dayLabel) \(visit.reminderDate.timeLabel)")
                    .accessibilityIdentifier("reminder-preview")
            }
        } header: {
            Text("알림")
        } footer: {
            Text("알림은 일정을 저장할 때 한 번 예약됩니다.")
        }
    }

    private var cleanName: String { visit.placeName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func setReminderEnabled(_ enabled: Bool) {
        visit.reminderEnabled = enabled
        guard enabled else { return }
        isRequestingPermission = true
        Task {
            defer { isRequestingPermission = false }
            do {
                if try await !store.requestReminderPermission() {
                    visit.reminderEnabled = false
                    reminderMessage = "설정에서 TripJJIM의 알림을 허용하면 방문 알림을 켤 수 있습니다."
                }
            } catch {
                visit.reminderEnabled = false
                reminderMessage = "알림 권한을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    private func save() {
        let calendar = Calendar.current
        visit.placeName = cleanName
        if isNew || visit.visitDate != original.visitDate {
            visit.visitDate = calendar.dateInterval(of: .minute, for: visit.visitDate)?.start ?? visit.visitDate
        }
        if let date = visit.customReminderDate, isNew || date != original.customReminderDate {
            visit.customReminderDate = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        }

        if visit.hasPastReminderChange(from: original) {
            reminderMessage = "알림 날짜와 시간을 현재 시각 이후로 선택해 주세요."
            return
        }
        visit.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo
        if onSave(visit) { dismiss() }
    }
}
