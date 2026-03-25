//
//  WeatherManager.swift
//  Stars
//
//  Integrates with Apple WeatherKit to fetch real-time weather conditions
//  and maps them to pixel-art weather effects for the game scene.
//

import CoreLocation
import WeatherKit

@MainActor
final class WeatherManager: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    // MARK: - Weather Effect Enum

    enum WeatherEffect: String {
        case clear        // no effect
        case rain         // pixel rain particles
        case heavyRain    // denser rain
        case snow         // pixel snow
        case thunderstorm // rain + occasional flash
        case fog          // subtle fog overlay
    }

    static let weatherDidChange = Notification.Name("stars.weatherDidChange")

    /// UserDefaults key for location-weather toggle.
    static let enabledKey = "stars.weather.enabled"

    /// Whether the user has opted in to location-based weather sync.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if newValue {
                startMonitoringInternal()
            } else {
                stopMonitoring()
                // Reset to clear when disabled
                if currentEffect != .clear {
                    currentEffect = .clear
                    temperature = nil
                    locationName = nil
                    NotificationCenter.default.post(name: Self.weatherDidChange, object: nil)
                }
            }
        }
    }

    private(set) var currentEffect: WeatherEffect = .clear
    private(set) var temperature: Double?   // celsius
    private(set) var locationName: String?

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    private var refreshTimer: Timer?
    private var lastLocation: CLLocation?

    // MARK: - Lifecycle

    func startMonitoring() {
        guard isEnabled else { return }
        startMonitoringInternal()
    }

    private func startMonitoringInternal() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()

        // If already authorised, kick off a location request immediately
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }

        // Periodic refresh every 30 minutes
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.locationManager.requestLocation()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.lastLocation = location
            await self?.fetchWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Location errors are non-fatal; keep current effect
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.locationManager.requestLocation()
            }
        }
    }

    // MARK: - Weather Fetching

    private func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            let condition = weather.currentWeather.condition
            let newEffect = mapCondition(condition)
            temperature = weather.currentWeather.temperature.value

            // Reverse-geocode for a human-readable location name
            let geocoder = CLGeocoder()
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                locationName = placemark.locality ?? placemark.administrativeArea
            }

            if newEffect != currentEffect {
                currentEffect = newEffect
                NotificationCenter.default.post(name: Self.weatherDidChange, object: nil)
            }
        } catch {
            // WeatherKit errors are non-fatal; keep the current effect
        }
    }

    // MARK: - Condition Mapping

    private func mapCondition(_ condition: WeatherCondition) -> WeatherEffect {
        switch condition {
        // Clear / cloudy — no visible effect
        case .clear, .mostlyClear, .partlyCloudy, .cloudy, .mostlyCloudy:
            return .clear

        // Rain
        case .rain, .drizzle:
            return .rain
        case .heavyRain:
            return .heavyRain

        // Snow / ice
        case .snow, .sleet, .freezingRain, .blizzard,
             .heavySnow, .flurries, .freezingDrizzle,
             .wintryMix, .blowingSnow:
            return .snow

        // Thunderstorm
        case .thunderstorms, .strongStorms,
             .isolatedThunderstorms, .scatteredThunderstorms:
            return .thunderstorm

        // Fog / haze
        case .foggy, .haze, .smoky:
            return .fog

        // Everything else → clear
        default:
            return .clear
        }
    }
}
