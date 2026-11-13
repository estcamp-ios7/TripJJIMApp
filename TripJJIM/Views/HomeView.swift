import SwiftUI

struct HomeView: View {
    let onTripCreated: (Trip.ID?) -> Void

    @State private var destination: Destination?
    @State private var didCreateTrip = false
    @State private var importedTripID: Trip.ID?

    private enum Destination: String, Identifiable {
        case recommendations, preferences, createTrip

        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("어떤 여행을 떠나볼까요?")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("나에게 맞는 방법으로 여행을 시작해 보세요.")
                        .font(.subheadline)
                        .readableSecondaryForeground()
                }
                .padding(.bottom, 4)

                featureCard(
                    "추천 여행 둘러보기",
                    description: "미리 준비된 여행 코스에서 마음에 드는 일정을 선택해 보세요.",
                    imageName: "HomeRecommendedTravel",
                    imageAlignment: .bottom,
                    destination: .recommendations
                )
                featureCard(
                    "내 취향으로 계획하기",
                    description: "간단한 질문에 답하고 나만의 여행 취향을 확인해 보세요.",
                    imageName: "HomePersonalizedTravel",
                    destination: .preferences
                )

                Button {
                    destination = .createTrip
                } label: {
                    HStack(spacing: 16) {
                        cardText("직접 계획하기", description: "가고 싶은 곳이 이미 정해져 있나요?")
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Color.tripAccent)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-create-trip")
            }
            .frame(maxWidth: 520)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.bottom, 12, for: .scrollContent)
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(item: $destination, onDismiss: finishTripCreation) { destination in
            switch destination {
            case .recommendations:
                NavigationStack {
                    RecommendedCourseListView { tripID in
                        importedTripID = tripID
                        self.destination = nil
                    }
                }
            case .preferences:
                TravelPreferenceOnboardingView { _ in }
            case .createTrip:
                TripEditorView(trip: nil) { _ in
                    didCreateTrip = true
                    self.destination = nil
                }
            }
        }
    }

    private func featureCard(
        _ title: String,
        description: String,
        imageName: String,
        imageAlignment: Alignment = .center,
        destination: Destination
    ) -> some View {
        Button {
            self.destination = destination
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .aspectRatio(64.0 / 27.0, contentMode: .fit)
                    .overlay(alignment: imageAlignment) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .accessibilityHidden(true)

                cardText(title, description: description)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.22))
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-\(destination.rawValue)")
    }

    private func cardText(_ title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .readableSecondaryForeground()
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func finishTripCreation() {
        guard didCreateTrip || importedTripID != nil else { return }
        didCreateTrip = false
        let tripID = importedTripID
        importedTripID = nil
        onTripCreated(tripID)
    }
}

#Preview("홈") {
    HomeView { _ in }
        .environment(PreviewData.makeStore())
}
