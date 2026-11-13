import Foundation

enum RecommendedCourseCatalog {
    enum LoadError: Error {
        case missingResource, invalidCatalog
    }

    static func load(from bundle: Bundle = .main) throws -> [RecommendedCourse] {
        guard let url = bundle.url(forResource: "RecommendedCourses", withExtension: "json") else {
            throw LoadError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> [RecommendedCourse] {
        let courses = try JSONDecoder().decode([RecommendedCourse].self, from: data)
        guard Set(courses.map(\.id)).count == courses.count,
              courses.allSatisfy(isValid) else {
            throw LoadError.invalidCatalog
        }
        return courses
    }

    static func matching(_ theme: TravelTheme?, in courses: [RecommendedCourse]) -> [RecommendedCourse] {
        guard let theme else { return courses }
        return courses.filter { $0.theme == theme }
    }

    private static func isValid(_ course: RecommendedCourse) -> Bool {
        let places = course.days.flatMap(\.places)
        return !course.days.isEmpty
            && course.days.map(\.number).sorted() == Array(1...course.dayCount)
            && Set(places.map(\.id)).count == places.count
            && course.days.allSatisfy { day in
                !day.places.isEmpty && day.places.map(\.order).sorted() == Array(1...day.places.count)
            }
            && places.allSatisfy { place in
                guard let coordinate = place.coordinate else { return true }
                return (-90...90).contains(coordinate.latitude)
                    && (-180...180).contains(coordinate.longitude)
                    && place.coordinateSource != nil
            }
    }
}
