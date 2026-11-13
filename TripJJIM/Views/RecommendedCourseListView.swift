import SwiftUI

struct RecommendedCourseListView: View {
    let onImported: (Trip.ID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var theme: TravelTheme?
    @State private var catalog: Result<[RecommendedCourse], Error>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("마음에 드는 여행을 발견해 보세요.")
                    .font(.subheadline)
                    .readableSecondaryForeground()

                if let catalog {
                    switch catalog {
                    case .success(let courses):
                        filters
                        courseList(RecommendedCourseCatalog.matching(theme, in: courses))
                    case .failure:
                        ContentUnavailableView(
                            "추천 코스를 불러올 수 없어요",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("추천 여행 코스")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("닫기") { dismiss() }
            }
        }
        .task {
            if catalog == nil { catalog = Result { try RecommendedCourseCatalog.load() } }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filter(nil)
                ForEach(TravelTheme.allCases, id: \.self) { filter($0) }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("여행 테마")
    }

    private func filter(_ option: TravelTheme?) -> some View {
        let selected = theme == option
        return Button {
            theme = option
        } label: {
            Text(option?.title ?? "전체")
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(selected ? Color.tripAccent.opacity(0.16) : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("course-theme-\(option?.rawValue ?? "all")")
    }

    @ViewBuilder
    private func courseList(_ courses: [RecommendedCourse]) -> some View {
        if courses.isEmpty {
            ContentUnavailableView("표시할 추천 코스가 없어요", systemImage: "map")
        } else {
            LazyVStack(spacing: 16) {
                ForEach(courses) { course in
                    NavigationLink {
                        RecommendedCourseDetailView(course: course, onImported: onImported)
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            RecommendedCourseArtwork(course: course)
                            HStack(alignment: .center, spacing: 12) {
                                RecommendedCourseHeading(course: course)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.tripAccent)
                                    .accessibilityHidden(true)
                            }
                            .padding(14)
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                        .clipShape(.rect(cornerRadius: 18))
                        .contentShape(.rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recommended-course-\(course.id)")
                }
            }
        }
    }
}

struct RecommendedCourseHeading: View {
    let course: RecommendedCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(course.title).font(.headline)
            Text(course.region)
                .font(.subheadline)
                .readableSecondaryForeground()
            Text("\(course.theme.title) · \(course.duration)")
                .font(.footnote.weight(.medium))
                .readableSecondaryForeground()
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct RecommendedCourseArtwork: View {
    let course: RecommendedCourse

    var body: some View {
        Color.clear
            .aspectRatio(64.0 / 27.0, contentMode: .fit)
            .overlay {
                if let name = course.imageName, let image = UIImage(named: name) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(.white)
                        }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var palette: [Color] {
        switch course.theme {
        case .nature: [.teal, .green]
        case .coast: [.blue, .cyan]
        case .culture: [.purple, .indigo]
        }
    }

    private var symbol: String {
        switch course.theme {
        case .nature: "leaf"
        case .coast: "water.waves"
        case .culture: "fork.knife"
        }
    }
}
