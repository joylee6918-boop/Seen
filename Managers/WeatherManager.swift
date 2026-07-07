import Foundation
import Combine
import CoreLocation

@MainActor
class WeatherManager: NSObject, ObservableObject {
    @Published var currentWeather: String = "☀️"
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    private func fetchWeather(latitude: Double, longitude: Double) async {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            currentWeather = weatherCodeToEmoji(response.current_weather.weathercode)
        } catch {
            print("获取天气失败: \(error)")
        }
    }

    private func weatherCodeToEmoji(_ code: Int) -> String {
        switch code {
        case 0:       return "☀️"
        case 1...3:   return "☁️"
        case 45, 48:  return "🌫"
        case 51...67: return "🌧"
        case 71...77: return "❄️"
        default:      return "☀️"
        }
    }
}

extension WeatherManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            await fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error)")
    }
}

struct WeatherResponse: Codable {
    let current_weather: CurrentWeather
    struct CurrentWeather: Codable {
        let weathercode: Int
    }
}
