// AsyncImageGridView.swift
// AsyncActorKit
// Demonstrates: TaskGroup fan-out for concurrent image loading

import SwiftUI

// MARK: - Model

struct WeatherIconItem: Identifiable, Sendable {
    let id: String   // icon code, e.g. "01d"
    let label: String
    var image: UIImage?
    var isLoading: Bool = false

    var url: URL? {
        URL(string: "https://openweathermap.org/img/wn/\(id)@2x.png")
    }
}

// MARK: - View

/// Demonstrates TaskGroup by fetching multiple weather icons concurrently.
struct AsyncImageGridView: View {
    @State private var items: [WeatherIconItem] = Self.allIcons
    @State private var isFetching = false
    @State private var elapsed: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TASKGROUP DEMO".uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text("Concurrent icon fetch")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                Spacer()
                if isFetching {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else if elapsed > 0 {
                    Text(String(format: "%.2fs", elapsed))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach($items) { $item in
                    IconCell(item: $item)
                }
            }

            // Fetch button
            Button(action: { Task { await fetchAllConcurrently() } }) {
                Label(isFetching ? "Fetching…" : "Fetch All (TaskGroup)", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isFetching ? Color.gray.opacity(0.3) : Color.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isFetching)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - TaskGroup fetch

    private func fetchAllConcurrently() async {
        guard !isFetching else { return }
        isFetching = true
        elapsed = 0

        // Reset images
        for i in items.indices { items[i].image = nil; items[i].isLoading = true }

        let start = Date()

        // Fan out — all icons fetched in parallel via TaskGroup
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for item in items {
                guard let url = item.url else { continue }
                group.addTask {
                    let img = try? await fetchImage(url: url)
                    return (item.id, img)
                }
            }

            for await (id, img) in group {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].image = img
                    items[index].isLoading = false
                }
            }
        }

        elapsed = Date().timeIntervalSince(start)
        isFetching = false
    }

    // MARK: - All icon codes

    static let allIcons: [WeatherIconItem] = [
        WeatherIconItem(id: "01d", label: "Clear"),
        WeatherIconItem(id: "02d", label: "P.Cloudy"),
        WeatherIconItem(id: "03d", label: "Cloudy"),
        WeatherIconItem(id: "04d", label: "Overcast"),
        WeatherIconItem(id: "09d", label: "Drizzle"),
        WeatherIconItem(id: "10d", label: "Rain"),
        WeatherIconItem(id: "11d", label: "Storm"),
        WeatherIconItem(id: "13d", label: "Snow"),
        WeatherIconItem(id: "50d", label: "Fog"),
        WeatherIconItem(id: "01n", label: "Clear N"),
        WeatherIconItem(id: "02n", label: "P.C. N"),
        WeatherIconItem(id: "10n", label: "Rain N"),
    ]
}

// MARK: - Icon Cell

private struct IconCell: View {
    @Binding var item: WeatherIconItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
                    .frame(height: 56)

                if item.isLoading {
                    ProgressView().scaleEffect(0.7).tint(.white)
                } else if let img = item.image {
                    Image(uiImage: img).resizable().scaledToFit().padding(6)
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            Text(item.label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Async image helper

private func fetchImage(url: URL) async throws -> UIImage? {
    let (data, _) = try await URLSession.shared.data(from: url)
    return UIImage(data: data)
}
