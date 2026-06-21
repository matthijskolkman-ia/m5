import SwiftUI

struct WeatherView: View {
    @ObservedObject var service: WeatherService
    @Binding var city: String
    @State private var cityInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "cloud.sun.fill").font(.system(size: 13)).foregroundColor(.blue)
                Text("Weather").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                if service.isLoading { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
            }.padding(.horizontal, 14).padding(.vertical, 8)

            // City input
            HStack(spacing: 6) {
                TextField("City", text: $cityInput).textFieldStyle(.roundedBorder).font(.system(size: 10))
                    .onSubmit { city = cityInput; service.fetch(for: city) }
                Button("Go") { city = cityInput; service.fetch(for: city) }
                    .font(.system(size: 10)).buttonStyle(.borderedProminent).controlSize(.small)
            }.padding(.horizontal, 14).padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.05))

            let w = service.weather
            if w.city != "—" {
                ScrollView {
                    VStack(spacing: 12) {
                        // Current
                        VStack(spacing: 4) {
                            Text(w.city).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                            Text(w.condition).font(.system(size: 12)).foregroundColor(.gray)
                            Text(String(format: "%.1f°C", w.temp))
                                .font(.system(size: 40, weight: .thin, design: .monospaced)).foregroundColor(.white)
                            HStack(spacing: 16) {
                                Label("Feels \(String(format: "%.0f°", w.feelsLike))", systemImage: "thermometer").font(.system(size: 9)).foregroundColor(.gray)
                                Label("\(w.humidity)%", systemImage: "humidity").font(.system(size: 9)).foregroundColor(.gray)
                                Label("\(String(format: "%.0f", w.windSpeed)) km/h", systemImage: "wind").font(.system(size: 9)).foregroundColor(.gray)
                            }
                        }.padding(12).background(Color.white.opacity(0.03)).cornerRadius(8).padding(.horizontal, 14)

                        // Forecast
                        VStack(alignment: .leading, spacing: 6) {
                            Text("5-Day Forecast").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                            ForEach(w.forecast) { day in
                                HStack {
                                    Text(day.date).font(.system(size: 11)).foregroundColor(.white.opacity(0.6)).frame(width: 50, alignment: .leading)
                                    Text(day.condition).font(.system(size: 10)).foregroundColor(.gray)
                                    Spacer()
                                    Text(String(format: "%.0f°", day.tempMin)).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                                    Text("—").font(.system(size: 8)).foregroundColor(.gray)
                                    Text(String(format: "%.0f°", day.tempMax)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.white)
                                }.padding(.horizontal, 14)
                            }
                        }
                    }.padding(.vertical, 8)
                }
            } else if let err = service.error {
                Text(err).font(.caption).foregroundColor(.red).padding()
            } else {
                Spacer()
                Text("Enter a city").font(.caption).foregroundColor(.gray)
                Spacer()
            }
        }
        .onAppear { cityInput = city }
    }
}
