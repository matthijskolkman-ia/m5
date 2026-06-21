import Foundation

struct WeatherData {
    var temp: Double = 0
    var feelsLike: Double = 0
    var humidity: Int = 0
    var windSpeed: Double = 0
    var condition: String = "—"
    var icon: String = "cloud"
    var city: String = "—"
    var forecast: [ForecastDay] = []
}

struct ForecastDay: Identifiable {
    let id = UUID()
    var date: String = ""
    var tempMax: Double = 0
    var tempMin: Double = 0
    var condition: String = ""
}

class WeatherService: ObservableObject {
    @Published var weather = WeatherData()
    @Published var isLoading = false
    @Published var error: String?

    // Open-Meteo: free, no key, unlimited calls
    // Uses geocoding first to get coordinates, then weather

    func fetch(for city: String) {
        isLoading = true; error = nil
        // Geocode city → coordinates
        let geoURL = "https://geocoding-api.open-meteo.com/v1/search?name=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)&count=1"
        guard let url = URL(string: geoURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let results = json["results"] as? [[String:Any]],
                  let first = results.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double,
                  let name = first["name"] as? String else {
                DispatchQueue.main.async { self?.isLoading = false; self?.error = "City not found" }; return
            }
            self.fetchWeather(lat: lat, lon: lon, city: name)
        }.resume()
    }

    private func fetchWeather(lat: Double, lon: Double, city: String) {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=5"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let current = json["current"] as? [String:Any],
                  let daily = json["daily"] as? [String:Any] else {
                DispatchQueue.main.async { self?.isLoading = false }; return
            }

            var w = WeatherData()
            w.city = city
            w.temp = current["temperature_2m"] as? Double ?? 0
            w.feelsLike = current["apparent_temperature"] as? Double ?? 0
            w.humidity = current["relative_humidity_2m"] as? Int ?? 0
            w.windSpeed = current["wind_speed_10m"] as? Double ?? 0
            w.condition = self.weatherDesc(current["weather_code"] as? Int ?? 0)

            // Forecast
            let dates = daily["time"] as? [String] ?? []
            let maxTemps = daily["temperature_2m_max"] as? [Double] ?? []
            let minTemps = daily["temperature_2m_min"] as? [Double] ?? []
            let codes = daily["weather_code"] as? [Int] ?? []
            w.forecast = (0..<min(5, dates.count)).map { i in
                ForecastDay(date: String(dates[i].suffix(5)), tempMax: maxTemps[i], tempMin: minTemps[i], condition: self.weatherDesc(codes[i]))
            }

            DispatchQueue.main.async { self.weather = w; self.isLoading = false }
        }.resume()
    }

    private func weatherDesc(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1,2,3: return "Partly cloudy"
        case 45,48: return "Fog"
        case 51,53,55: return "Drizzle"
        case 61,63,65: return "Rain"
        case 71,73,75: return "Snow"
        case 80,81,82: return "Showers"
        case 95,96,99: return "Thunderstorm"
        default: return "Cloudy"
        }
    }
}
