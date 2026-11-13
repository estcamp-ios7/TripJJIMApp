import SwiftUI

struct VisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TripStore.self) private var store
    @State private var visit: Visit
    @State private var isRequestingPermission = false
    @State private var reminderMessage: String?
    @State private var memo: String
    @State private var searchingPlace = false
    @State private var saveError: String?
    @State private var isDeleting = false
    @State private var deleteFailed = false

    private let region: String?
    private let tripRegionLocation: TripRegionLocation?
    private let original: Visit
    private let isNew: Bool
    private let onDelete: (() -> Bool)?
    private let onSave: (Visit) -> Bool

    init(
        visit: Visit,
        isNew: Bool,
        region: String?,
        tripRegionLocation: TripRegionLocation? = nil,
        onDelete: (() -> Bool)? = nil,
        onSave: @escaping (Visit) -> Bool
    ) {
        _visit = State(initialValue: visit)
        _memo = State(initialValue: visit.memo ?? "")
        self.region = region
        self.tripRegionLocation = tripRegionLocation
        original = visit
        self.isNew = isNew
        self.onDelete = onDelete
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
                            .readableSecondaryForeground()
                    }
                    Button {
                        searchingPlace = true
                    } label: {
                        Label(isNew ? "장소 검색" : "장소 변경", systemImage: "magnifyingglass")
                    }
                    DatePicker("방문 날짜", selection: $visit.visitDate, displayedComponents: .date)
                        .accessibilityIdentifier("visit-date")
                    DatePicker("방문 시각", selection: $visit.visitDate, displayedComponents: .hourAndMinute)
                }
                Section("방문 메모") {
                    TextField("메모를 입력해 주세요", text: $memo, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("visit-memo")
                }
                reminderSection
                if !isNew, onDelete != nil {
                    Section {
                        Button("일정 삭제", systemImage: "trash", role: .destructive) {
                            isDeleting = true
                        }
                    }
                }
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
            .sheet(isPresented: $searchingPlace) {
                NavigationStack {
                    PlaceSearchView(region: region, tripRegionLocation: tripRegionLocation) { place in
                        visit.placeName = place.name
                        visit.coordinate = place.coordinate
                        visit.address = place.address
                    }
                }
            }
            .alert("일정을 저장할 수 없어요", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .interactiveDismissDisabled(isRequestingPermission)
            .alert("방문 일정을 삭제할까요?", isPresented: $isDeleting) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive, action: deleteVisit)
            } message: {
                Text("‘\(original.placeName)’ 일정의 알림도 함께 삭제됩니다.")
            }
            .alert("일정을 삭제할 수 없어요", isPresented: $deleteFailed) {
                Button("확인", role: .cancel) {}
            }
            .alert("일정 알림", isPresented: Binding(
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
            Toggle("일정 알림", isOn: Binding(
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
            }
        } header: {
            Text("알림")
        } footer: {
            Text("선택한 일시에 한 번 알림을 보내드려요.")
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
                    reminderMessage = "설정에서 TripJJIM의 알림을 허용하면 일정 알림을 켤 수 있습니다."
                }
            } catch {
                visit.reminderEnabled = false
                reminderMessage = "알림 권한을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    private func deleteVisit() {
        if onDelete?() == true {
            dismiss()
        } else {
            deleteFailed = true
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
        if onSave(visit) {
            dismiss()
        } else {
            saveError = store.storageError ?? "여행이 여전히 있는지 확인하고 다시 시도해 주세요."
            store.storageError = nil
        }
    }
}
