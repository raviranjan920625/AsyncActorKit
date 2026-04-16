// WeatherDashboardView.swift
// AsyncActorKit — Minimalist Weather Dashboard

import SwiftUI

// MARK: - Main Dashboard

struct WeatherDashboardView: View {
    @State private var viewModel = WeatherViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            switch viewModel.loadingState {
            case .idle:
                EmptyView()
            case .loading:
                LoadingView()
            case .loaded:
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        if let forecast = viewModel.forecast {
                            HeroCard(city: forecast.city, item: forecast.list.first)
                        }
                        if !viewModel.dailyForecasts.isEmpty {
                            DailyStripView(
                                days: viewModel.dailyForecasts,
                                selected: $viewModel.selectedDay
                            )
                        }
                        if let selected = viewModel.selectedDay {
                            HourlyScrollView(items: selected.items)
                            WeatherMetricsGrid(day: selected)
                        }
                        ActorDiagnosticsCard(text: viewModel.actorDiagnostics)
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .refreshable { await viewModel.refresh() }

            case .failed(let message):
                ErrorView(message: message) { viewModel.loadForecast() }
            }
        }
        .task { viewModel.loadForecast() }
        .navigationTitle("")
    }
}

// MARK: - Background

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.10),
                Color(red: 0.08, green: 0.10, blue: 0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Hero Card

private struct HeroCard: View {
    let city: City
    let item: ForecastItem?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 4) {
            // City + country
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(city.name), \(city.country)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Temperature
            if let item {
                Text("\(Int(item.main.tempCelsius))°")
                    .font(.system(size: 80, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(item.primaryCondition?.description.capitalized ?? "")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 20) {
                    Label("\(Int(item.main.humidity))%", systemImage: "humidity.fill")
                    Label("\(Int(item.wind.speedKmh)) km/h", systemImage: "wind")
                    Label("\(Int(item.pop * 100))%", systemImage: "drop.fill")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 24))
        .onAppear {
            withAnimation(.spring(duration: 0.7)) { appeared = true }
        }
    }
}

// MARK: - Daily Strip

private struct DailyStripView: View {
    let days: [DailyForecast]
    @Binding var selected: DailyForecast?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("5-Day Forecast")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(days) { day in
                        DayPill(day: day, isSelected: selected?.id == day.id)
                            .onTapGesture { selected = day }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct DayPill: View {
    let day: DailyForecast
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(day.dayLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)

            if let cond = day.dominantCondition {
                Image(systemName: cond.systemImageName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    .symbolRenderingMode(.multicolor)
            }

            Text("\(Int(day.maxCelsius))°")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)

            Text("\(Int(day.minCelsius))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            isSelected
            ? AnyShapeStyle(LinearGradient(colors: [Color(red:0.3,green:0.5,blue:1), Color(red:0.2,green:0.35,blue:0.85)], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(.ultraThinMaterial.opacity(0.2)),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Hourly Scroll

private struct HourlyScrollView: View {
    let items: [ForecastItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Hourly")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        VStack(spacing: 8) {
                            Text(item.timeLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let cond = item.primaryCondition {
                                Image(systemName: cond.systemImageName)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.body)
                            }

                            Text("\(Int(item.main.tempCelsius))°")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white)

                            // Rain probability bar
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: 4, height: CGFloat(item.pop) * 32)
                                    .frame(height: 32, alignment: .bottom)
                                Text("\(Int(item.pop * 100))%")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Metrics Grid

private struct WeatherMetricsGrid: View {
    let day: DailyForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Details")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(icon: "humidity.fill",  label: "Humidity",   value: "\(day.avgHumidity)%")
                MetricTile(icon: "wind",            label: "Wind",      value: String(format: "%.1f km/h", day.avgWindSpeed * 3.6))
                MetricTile(icon: "drop.fill",       label: "Rain %",    value: "\(Int(day.maxPop * 100))%")
                MetricTile(icon: "thermometer.medium", label: "Range", value: "\(Int(day.minCelsius))° – \(Int(day.maxCelsius))°")
            }
        }
    }
}

private struct MetricTile: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Actor Diagnostics Card

private struct ActorDiagnosticsCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Actor Diagnostics")
            Text(text.isEmpty ? "No data yet" : text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.green.opacity(0.8))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 1)

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
            }
            Text("Fetching forecast…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 48))

            Text("Something went wrong")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: Capsule())
            }
        }
        .padding(40)
    }
}

// MARK: - Shared label

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}
