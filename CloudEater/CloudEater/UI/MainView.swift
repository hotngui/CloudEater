//
// Created by Joey Jarosz on 8/24/24.
// Copyright (c) 2024 hot-n-GUI, LLC. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dismiss) var dismiss

    @AppStorage("numberOfChunks") var numberOfChunksUD = ChunkGenerator.defaultNumberOfChunks
    @AppStorage("sizeOfChunksInBytes") var sizeOfChunksInBytesUD = ChunkGenerator.defaultSizeOfChunkInBytes

    @State private var numberOfChunks: Int = ChunkGenerator.defaultNumberOfChunks
    @State private var sizeOfChunksInBytes: Double = ChunkGenerator.defaultSizeOfChunkInBytes

    @State private var dummyRefresher = false
    @State private var isGeneratingFiles = false
    @State private var isDeletingFiles = false
    @State private var isBusy = false
    @State private var isShowingError = false
    @State private var errorMessage: String?
    @State private var cloudSpaceSize: Double = 0.0
    @State private var accountStatusAlertShown = false

    private let generator = ChunkGenerator()
    
    private let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 3
        formatter.numberFormatter.minimumFractionDigits = 3
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    Stepper("Chunk Size: \(convert(sizeOfChunksInBytes, from: .bytes, to: .megabytes).formatted())",
                            onIncrement: { incrementFileSizeValue() },
                            onDecrement: { decrementFileSizeValue() })

                    Stepper("Number Of Chunks: \(numberOfChunks)",
                            value: $numberOfChunks,
                            in: 1...100,
                            step: ChunkGenerator.defaultNumberOfChunks)

                    HStack {
                        deleteOneChunkButton()
                        Spacer()
                        deleteAllChunksButton()
                        Spacer()
                        generateFilesButton()
                    }
                }
                
                Section {
                    HStack {
                        Text("Data Size:")
                        Spacer()
                        Text("\(formatter.string(from: convert(cloudSpaceSize, from: .bytes, to: .gigabytes)))")
                            .monospaced()
                    }
                } header : {
                    Text("Eaten")
                        .padding(.top, -12)
                }
            }
            .navigationTitle("Cloud Eater")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isBusy)
            .overlay {
                if isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.accentColor)
                }
            }
            .id(dummyRefresher)
            
            // Useful pull-to-refresh if you expect disk space to be consumed by another app running in the background
            .refreshable {
                dummyRefresher.toggle()
            }
            
            // Useful when going back-and-forth between apps..
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    dummyRefresher.toggle()
                }
            }
            
            // When we use the initializer variant of the `Stepper` view that we are using we run into issues
            // when we try to read/write from `AppStorage` directly so we set/get them as seperate points in time...
            .onAppear {
                sizeOfChunksInBytes = sizeOfChunksInBytesUD
                numberOfChunks = numberOfChunksUD
            }
            .onChange(of: sizeOfChunksInBytes) { _, value in
                sizeOfChunksInBytesUD = value
            }
            .onChange(of: numberOfChunks) { _, value in
                numberOfChunksUD = value
            }
        }
        
        .alert("No iCloud Account", isPresented: $accountStatusAlertShown, actions: {
            Button("Cancel", role: .cancel, action: {})
            
            Button("Go to Settings") {
                Task {
                    if let url = URL(string: "App-prefs:root=CASTLE") {
                        await UIApplication.shared.open(url)
                    }
                }
            }
        }, message: {
            Text("You need to be signed into an iCloud account to use this tool.")
        })
        
        .task {
            if let status = try? await CloudKitService().checkAccountStatus(), status != .available {
                accountStatusAlertShown.toggle()
            }
            
            await countSize()
        }
    }
    
    private func countSize(_ delay: UInt64 = 0) async {
        cloudSpaceSize = (try? await generator.usedCloudSpace(delay)) ?? 0
    }

    @ViewBuilder
    private func deleteOneChunkButton() -> some View {
        Button("Delete One File", role: .destructive) {
            isBusy.toggle()
            
            Task {
                try? await generator.removeFiles(1)
                await countSize(3)

                isBusy.toggle()
            }
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private func deleteAllChunksButton() -> some View {
        Button("Delete All Files", role: .destructive) {
            isDeletingFiles.toggle()
        }
        .buttonStyle(.borderedProminent)
        .alert("Delete All Files", isPresented: $isDeletingFiles) {
            Button("DELETE", role: .destructive) {
                isBusy.toggle()
                
                Task {
                    try! await generator.removeFiles()
                    await countSize(3)

                    isBusy.toggle()
                }
            }
        } message: {
            Text("Do you really want to delete all the files created by this tool?")
        }
    }

    @ViewBuilder
    private func generateFilesButton() -> some View {
        Button("Generate Files", role: .none) {
            isGeneratingFiles.toggle()
            isBusy.toggle()
            
            Task {
                do {
                    try await generator.generate(numberOfChunks: numberOfChunks, sizeOfChunksInBytes: sizeOfChunksInBytes)
                    await countSize(3)
                    isGeneratingFiles.toggle()
                    isBusy.toggle()
                } catch {
                    errorMessage = error.localizedDescription
                    isBusy.toggle()
                    isGeneratingFiles.toggle()
                    isShowingError.toggle()
                }
            }
            
        }
        .buttonStyle(.borderedProminent)
        .alert(isPresented: $isShowingError) {
            Alert(
                title: Text("File Generation"),
                message: Text("\(errorMessage ?? "")")
            )
        }
    }

    // MARK - Stepper Support
    
    /// Increments the size of the files to be generated. The effective `step` value changes such that when the value is less than 100 it steps by 10, otherwise it steps by 100.
    /// This makes the range 10-100 by 10, 200-1000 by 100
    ///
    private func incrementFileSizeValue() {
        if sizeOfChunksInBytes >= (ChunkGenerator.defaultSizeOfChunkInBytes * 10) {
            return
        }
        if sizeOfChunksInBytes >= ChunkGenerator.defaultSizeOfChunkInBytes {
            sizeOfChunksInBytes += ChunkGenerator.defaultSizeOfChunkInBytes
        } else {
            sizeOfChunksInBytes += ChunkGenerator.defaultSizeOfChunkInBytes / 10
        }
    }
    
    /// Decrements the size of the files to be generated. The effective `step` value changes such that when the value is less than 100 it steps by 10, otherwise it steps by 100.
    /// This makes the range 10-100 by 10, 200-1000 by 100
    ///
    private func decrementFileSizeValue() {
        if sizeOfChunksInBytes <=  (ChunkGenerator.defaultSizeOfChunkInBytes / 10) {
            return
        }
        if sizeOfChunksInBytes <= ChunkGenerator.defaultSizeOfChunkInBytes {
            sizeOfChunksInBytes -= ChunkGenerator.defaultSizeOfChunkInBytes / 10
        } else {
            sizeOfChunksInBytes -= ChunkGenerator.defaultSizeOfChunkInBytes
        }
    }
    
    // MARK - Utilities
    
    private func convert(_ value: Double, from inUnit: UnitInformationStorage, to outUnit: UnitInformationStorage) -> Measurement<UnitInformationStorage> {
        return Measurement<UnitInformationStorage>(value: value, unit: inUnit).converted(to: outUnit)
    }
}

#Preview {
    MainView()
}
