import SwiftUI

struct RecommendedCourseImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TripStore.self) private var store
    @State private var title: String
    @State private var startDate = Date.now
    @State private var isSaving = false
    @State private var errorMessage: String?

    let course: RecommendedCourse
    let onSaved: (Trip.ID) -> Void

    init(course: RecommendedCourse, onSaved: @escaping (Trip.ID) -> Void) {
        self.course = course
        self.onSaved = onSaved
        _title = State(initialValue: course.title)
    }

    private var calendar: Calendar { .current }
    private var endDate: Date? {
        try? course.visitDay(course.dayCount, starting: startDate, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("여행 정보") {
                    TextField("여행 제목", text: $title)
                        .accessibilityIdentifier("course-import-title")
                    LabeledContent("지역", value: course.region)
                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                        .accessibilityIdentifier("course-import-start")
                    LabeledContent("종료일", value: endDate?.dayLabel ?? "계산할 수 없어요")
                }
                Section {
                    Text("모든 장소를 저장해요. 위치가 없는 장소는 저장 후 장소 검색에서 지정할 수 있어요.")
                    Text("방문 시각은 미정으로, 알림은 꺼진 상태로 저장해요.")
                } header: {
                    Text("가져올 일정")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                ForEach(course.days.sorted { $0.number < $1.number }) { day in
                    Section {
                        ForEach(day.places.sorted { $0.order < $1.order }) { place in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(place.order). \(place.name)").font(.headline)
                                Text("\(place.category.title) · \(place.area)")
                                    .foregroundStyle(.secondary)
                                if let time = place.suggestedTime {
                                    Label("권장 시간대 · \(time)", systemImage: "clock")
                                }
                                if place.coordinate == nil {
                                    Label("지도 위치 미지정", systemImage: "mappin.slash")
                                }
                            }
                            .font(.subheadline)
                            .padding(.vertical, 4)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    } header: {
                        let date = try? course.visitDay(day.number, starting: startDate, calendar: calendar)
                        Text("\(day.number)일 차 · \(date?.dayLabel ?? "날짜 미정")")
                    }
                }
            }
            .navigationTitle("추천 코스 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("여행 저장", action: save)
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || endDate == nil)
                        .accessibilityIdentifier("save-imported-course")
                }
            }
            .interactiveDismissDisabled(isSaving)
            .alert("여행을 저장할 수 없어요", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        guard !isSaving, let endDate else { return }
        isSaving = true
        do {
            let visits = try course.makeVisits(starting: startDate, calendar: calendar)
            let id = try store.saveTrip(name: title, startDate: startDate, endDate: endDate,
                                        region: course.region, id: nil, initialVisits: visits)
            onSaved(id)
        } catch {
            errorMessage = store.storageError ?? error.localizedDescription
            store.storageError = nil
            isSaving = false
        }
    }
}
