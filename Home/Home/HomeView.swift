import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Good to see you! 🐾")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        FeatureCard(
                            icon: "heart.fill",
                            title: "Pet Care",
                            description: "Track your pet's health and activities"
                        )
                        FeatureCard(
                            icon: "calendar",
                            title: "Appointments",
                            description: "Schedule vet visits and grooming"
                        )
                        FeatureCard(
                            icon: "photo.fill",
                            title: "Memories",
                            description: "Save precious moments with your pets"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
