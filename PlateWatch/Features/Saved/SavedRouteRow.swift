import SwiftUI

struct SavedRouteRow: View {
    let route: SavedRoute

    var body: some View {
        VStack(alignment: .leading) {
            Text(route.name)
                .font(.subheadline.weight(.semibold))
            if let score = route.lastDensityScore {
                Text("Density score \(Int(score))/100")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
