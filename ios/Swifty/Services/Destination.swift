import Foundation
import CoreLocation
import MapKit

/// 사용자가 지도를 탭하거나 검색해서 고른 목적지.
struct Destination: Identifiable, Equatable {
    let id: UUID
    var name: String
    var subtitle: String?
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(), name: String, subtitle: String? = nil, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        let title = mapItem.name ?? Fmt.coordinate(coordinate)
        self.init(name: title,
                  subtitle: mapItem.placemark.title,
                  coordinate: coordinate)
    }

    /// 지도를 길게 눌러 찍은 지점.
    static func droppedPin(at coordinate: CLLocationCoordinate2D) -> Destination {
        Destination(name: "목적지",
                    subtitle: Fmt.coordinate(coordinate),
                    coordinate: coordinate)
    }

    static func == (lhs: Destination, rhs: Destination) -> Bool {
        lhs.id == rhs.id && lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - 영구 저장

extension Destination {
    /// 앱을 껐다 켜도, 그리고 오프라인 상태로 시작해도 목적지를 유지하기 위한 직렬화.
    private struct Stored: Codable {
        var id: UUID
        var name: String
        var subtitle: String?
        var latitude: Double
        var longitude: Double
    }

    private static let storageKey = "swifty.destination"

    func persist() {
        let stored = Stored(id: id, name: name, subtitle: subtitle,
                            latitude: latitude, longitude: longitude)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static func loadPersisted() -> Destination? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return nil }
        return Destination(id: stored.id,
                           name: stored.name,
                           subtitle: stored.subtitle,
                           coordinate: CLLocationCoordinate2D(latitude: stored.latitude,
                                                              longitude: stored.longitude))
    }
}
