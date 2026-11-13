import SwiftUI

struct TravelPreferenceOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preference = TravelPreference()
    @State private var step: Step? = .region
    @State private var editingFromSummary = false

    let onComplete: (TravelPreference) -> Void

    private enum Step: Int, CaseIterable {
        case region = 1, duration, theme, dailyVisits

        var label: String {
            switch self {
            case .region: "지역"
            case .duration: "기간"
            case .theme: "여행 분위기"
            case .dailyVisits: "하루 방문 장소 수"
            }
        }

        var question: String {
            switch self {
            case .region: "어디로 여행을 떠나고 싶나요?"
            case .duration: "여행 기간은 어느 정도인가요?"
            case .theme: "어떤 분위기의 여행을 좋아하나요?"
            case .dailyVisits: "하루에 몇 곳을 방문하고 싶나요?"
            }
        }

        var detail: String {
            switch self {
            case .region: "원하는 지역을 선택해 주세요."
            case .duration: "원하는 여행 기간을 선택해 주세요."
            case .theme: "가장 마음에 드는 여행 스타일을 골라 주세요."
            case .dailyVisits: "식당과 카페를 포함해 하루에 방문하고 싶은 장소 수를 선택해 주세요."
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let step {
                        progress(for: step)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(step.question).font(.title.bold()).accessibilityAddTraits(.isHeader)
                            Text(step.detail).font(.subheadline).readableSecondaryForeground()
                        }
                        options(for: step)
                    } else {
                        summary
                    }
                }
                .id(step)
                .frame(maxWidth: 520)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
            .navigationTitle("여행 취향")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("preference-close")
                }
            }
        }
        .tint(.tripAccent)
    }

    private func progress(for step: Step) -> some View {
        let total = Step.allCases.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("STEP \(step.rawValue) / \(total)")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(step.rawValue), total: Double(total))
                .accessibilityLabel("질문 진행률")
        }
    }

    @ViewBuilder
    private func options(for step: Step) -> some View {
        VStack(spacing: 10) {
            switch step {
            case .region:
                ForEach(["제주", "부산"], id: \.self) { name in
                    option(name, value: .selected(name), selection: $preference.region)
                }
                if case .selected(let name) = preference.region, !["제주", "부산"].contains(name) {
                    option(name, value: .selected(name), selection: $preference.region)
                }
                option("아직 정하지 않았어요", value: .undecided, selection: $preference.region)
                NavigationLink {
                    TripRegionSearchView { selection in
                        preference.region = .selected(selection.name)
                    }
                } label: {
                    Label("다른 지역 검색", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            case .duration:
                ForEach(TravelPreference.Duration.allCases, id: \.self) { duration in
                    option(duration.title, value: duration, selection: $preference.duration)
                }
            case .theme:
                ForEach(TravelTheme.allCases, id: \.self) { theme in
                    option(theme.title, value: theme, selection: $preference.theme)
                }
            case .dailyVisits:
                ForEach(TravelPreference.DailyVisits.allCases, id: \.self) { visits in
                    option(visits.title, value: visits, selection: $preference.dailyVisits)
                }
            }
        }
    }

    private func option<Value: Equatable>(_ title: String, value: Value, selection: Binding<Value?>) -> some View {
        let selected = selection.wrappedValue == value
        return Button {
            selection.wrappedValue = value
        } label: {
            HStack(spacing: 12) {
                Text(title).font(.body.weight(.medium))
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.tripAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .background(selected ? Color.tripAccent.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground),
                        in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Color.tripAccent : .clear)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("선택한 여행 취향")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(Step.allCases, id: \.self) { item in
                Button {
                    editingFromSummary = true
                    step = item
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label).font(.subheadline).readableSecondaryForeground()
                            Text(answer(for: item) ?? "선택하지 않음").font(.headline)
                        }
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(Color.tripAccent).accessibilityHidden(true)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("답변 수정")
                .accessibilityIdentifier("preference-edit-\(item.rawValue)")
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if let step {
                if !editingFromSummary, let previous = Step(rawValue: step.rawValue - 1) {
                    Button("이전") { self.step = previous }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                primaryButton(editingFromSummary ? "답변 수정 완료" : "다음") {
                    self.step = editingFromSummary ? nil : Step(rawValue: step.rawValue + 1)
                    editingFromSummary = false
                }
                .disabled(answer(for: step) == nil)
            } else {
                primaryButton("취향 확인 완료") {
                    onComplete(preference)
                    dismiss()
                }
            }
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }

    private func answer(for step: Step) -> String? {
        switch step {
        case .region: preference.region?.title
        case .duration: preference.duration?.title
        case .theme: preference.theme?.title
        case .dailyVisits: preference.dailyVisits?.title
        }
    }
}
