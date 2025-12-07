//
//  StationSearchSheet.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/7/25.
//

import SwiftUI
import MapKit

struct StationSearchContent: View {
    @Bindable var viewModel: SessionDetailViewModel
    @Bindable var stationDataViewModel: StationDataViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search train stations", text: $stationDataViewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            let region = viewModel.calculateSearchRegion()
                            await stationDataViewModel.searchStations(region: region)
                        }
                    }
                if !stationDataViewModel.searchQuery.isEmpty {
                    Button {
                        stationDataViewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            // Content
            if stationDataViewModel.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if let error = stationDataViewModel.searchError {
                Spacer()
                ContentUnavailableView(
                    "Search Failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Spacer()
            } else if stationDataViewModel.searchResults.isEmpty {
                Spacer()
                if stationDataViewModel.searchQuery.isEmpty {
                    ContentUnavailableView(
                        "Search for Stations",
                        systemImage: "train.side.front.car",
                        description: Text("Enter a station name to search nearby train stations")
                    )
                } else {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No train stations found for \"\(stationDataViewModel.searchQuery)\"")
                    )
                }
                Spacer()
            } else {
                List(stationDataViewModel.searchResults, id: \.self) { item in
                    Button {
                        viewModel.addStationFromMapItem(item)
                        stationDataViewModel.clearSearch()
                        viewModel.sheetContent = .tabBar
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown Station")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.title2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    StationSearchContent(
        viewModel: SessionDetailViewModel(session: TrackingSession(name: "Test")),
        stationDataViewModel: StationDataViewModel()
    )
}
