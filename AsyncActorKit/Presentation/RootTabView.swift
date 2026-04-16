// RootTabView.swift
// AsyncActorKit
// Root SwiftUI view — uses .task {} lifecycle for structured concurrency

import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WeatherDashboardView()
                    .navigationTitle("Weather")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Dashboard", systemImage: "cloud.sun.fill") }
            .tag(AppTab.dashboard)

            NavigationStack {
                ConcurrencyDemoView()
                    .navigationTitle("Concurrency")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Demos", systemImage: "bolt.fill") }
            .tag(AppTab.demos)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Tab Enum

enum AppTab { case dashboard, demos }

// MARK: - Concurrency Demo Screen

struct ConcurrencyDemoView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.08, green: 0.10, blue: 0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    AsyncImageGridView()
                    ActorExplainerCard()
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }
}

// MARK: - Actor Explainer Card

private struct ActorExplainerCard: View {
    private let concepts: [(icon: String, title: String, subtitle: String)] = [
        ("lock.shield.fill",       "Actor Isolation",     "Mutable state protected by compile-time isolation."),
        ("arrow.triangle.2.circlepath", "Reentrancy",     "Actors may interleave tasks at suspension points."),
        ("bolt.horizontal.fill",   "Async / Await",       "Cooperative thread pool — no blocking."),
        ("square.stack.3d.up.fill","TaskGroup Fan-out",   "Parallel child tasks with structured lifetimes."),
        ("waveform.path",          "AsyncStream",         "Bridges callbacks & delegates to async sequences."),
        ("arrow.up.arrow.down.circle.fill", "Continuation", "withCheckedThrowingContinuation wraps legacy APIs."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SWIFT CONCURRENCY CONCEPTS".uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            ForEach(concepts, id: \.title) { concept in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: concept.icon)
                        .symbolRenderingMode(.multicolor)
                        .font(.title3)
                        .frame(width: 32, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(concept.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(concept.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                if concept.title != concepts.last?.title {
                    Divider().background(.white.opacity(0.08))
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    RootTabView()
}
