import SwiftUI
import SwiftData

@main
struct ShiguangApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var weatherManager = WeatherManager()
    @StateObject private var messageStore = MessageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(weatherManager)
                .environmentObject(messageStore)
                .onAppear {
                    weatherManager.requestLocation()
                }
        }
        .modelContainer(for: [
            Inspiration.self,
            DailyMood.self,
            Habit.self,
            WorkoutSession.self,
            CheckIn.self
        ])
    }
}
