import SwiftUI
import MapKit
import CoreLocation

/// The main map screen. Apple `Map` view with annotated camera pins, a filter
/// chip row, and a "Center on me" button. The first time the map view appears
/// we request when-in-use location authorization (per the JIT rule); we
/// never request at launch.
struct MapView: View {
    @EnvironmentObject private var appState: AppState

    @State private var cameraPosition: MapCameraPosition = .automatic

    @State private var enabledTypes: Set<CameraType> = Set(CameraType.allCases)
    @State private var selectedCamera: Camera?
    @State private var visibleBox: (south: Double, west: Double, north: Double, east: Double) = (
        south: 37.20, west: -122.30, north: 37.50, east: -121.70
    )
    @State private var hasCenteredOnUser = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(visiblePins, id: \.id) { camera in
                    Annotation(camera.type.displayName, coordinate: camera.coordinate) {
                        CameraPinAnnotation(type: camera.type)
                            .onTapGesture { selectedCamera = camera }
                    }
                }
                #if DEBUG
                if !CommandLine.arguments.contains("-platewatch.skipLocationPrompt") {
                    UserAnnotation()
                }
                #else
                UserAnnotation()
                #endif
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { ctx in
                let region = ctx.region
                visibleBox = (
                    south: region.center.latitude - region.span.latitudeDelta / 2,
                    west:  region.center.longitude - region.span.longitudeDelta / 2,
                    north: region.center.latitude + region.span.latitudeDelta / 2,
                    east:  region.center.longitude + region.span.longitudeDelta / 2
                )
            }

            VStack(alignment: .trailing, spacing: 12) {
                Button {
                    centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Theme.primary)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Center on my location")
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)

            VStack {
                MapFilterBar(enabledTypes: $enabledTypes)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                Spacer()
            }
        }
        .navigationTitle("Cameras")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedCamera) { camera in
            CameraDetailSheet(camera: camera)
                .presentationDetents([.medium, .large])
        }
        .task {
            // Sync the local store reference with the app's shared store.
            // We render from the shared store but published @StateObject above
            // gives us a clean lifecycle.
        }
        .onAppear {
            // Just-in-time location request. The risk profile is explicit:
            // we never request at launch, only here on first map view.
            #if DEBUG
            let skipLocationPrompt = CommandLine.arguments.contains("-platewatch.skipLocationPrompt")
            #else
            let skipLocationPrompt = false
            #endif
            if !appState.hasRequestedLocationOnce && !skipLocationPrompt {
                appState.locationService.requestWhenInUseAuthorizationIfNeeded()
                appState.markLocationRequested()
            }
            PortfolioAnalytics.shared.track(PortfolioEvent.screenViewed,
                                            ["screen": "map"])
        }
        // Center automatically the first time the user's location becomes
        // available. Prior to this, `.automatic` was fitting the Cupertino
        // seed pins so a San Antonio user saw California by default — even
        // after granting location. This actively drives the camera to the
        // user's fix once, then respects any manual pan/zoom afterwards.
        .onChange(of: appState.locationService.currentLocation) { _, loc in
            guard !hasCenteredOnUser, let loc else { return }
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
                )
            )
            hasCenteredOnUser = true
        }
    }

    // MARK: - Derived

    private var visiblePins: [Camera] {
        let padDeg = 0.02
        let inBox = appState.cameraStore.bbox(
            south: visibleBox.south - padDeg,
            west:  visibleBox.west - padDeg,
            north: visibleBox.north + padDeg,
            east:  visibleBox.east + padDeg
        )
        return inBox.filter { enabledTypes.contains($0.type) }
    }

    private func centerOnUser() {
        appState.locationService.requestWhenInUseAuthorizationIfNeeded()
        appState.locationService.requestOneShotLocation()
        if let loc = appState.locationService.currentLocation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
            hasCenteredOnUser = true
        }
    }
}
