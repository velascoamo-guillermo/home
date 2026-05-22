import SwiftUI

struct SFSymbolPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(filtered, id: \.self) { sym in
                        Button {
                            selection = sym
                            dismiss()
                        } label: {
                            Image(systemName: sym)
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .foregroundStyle(selection == sym ? .white : .primary)
                                .background(selection == sym ? Color.accentColor : Color(.secondarySystemFill))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        .accessibilityLabel(sym)
                    }
                }
                .padding()
            }
            .searchable(text: $query, prompt: "Search symbols")
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var filtered: [String] {
        query.isEmpty ? Self.symbols : Self.symbols.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    static let symbols: [String] = [
        // Home & Rooms
        "house", "house.fill", "house.lodge", "building.2", "door.left.hand.open",
        "window.casement", "bed.double", "sofa", "chair", "table.furniture",
        "bathtub", "shower", "toilet",
        // Utilities
        "drop", "drop.fill", "flame", "flame.fill", "bolt", "bolt.fill",
        "thermometer", "thermometer.sun", "fan", "fan.fill", "lightbulb",
        "lightbulb.fill", "power", "powerplug", "powerplug.fill", "air.purifier",
        // Tools & Repairs
        "wrench", "wrench.fill", "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        "hammer", "hammer.fill", "screwdriver", "screwdriver.fill", "pliers",
        "ruler", "ruler.fill", "paintbrush", "paintbrush.fill", "paintbrush.pointed",
        // Cleaning
        "trash", "trash.fill", "bubbles.and.sparkles", "bubbles.and.sparkles.fill",
        "sparkle", "sparkles", "spray.and.sparkles", "spray.and.sparkles.fill",
        "shower.handheld", "washer", "washer.fill", "dryer", "dryer.fill",
        // Garden & Nature
        "leaf", "leaf.fill", "tree", "tree.fill", "flower", "sun.max", "sun.max.fill",
        "cloud.rain", "cloud.rain.fill", "cloud.snow", "scissors", "scissors.fill",
        // Kitchen & Food
        "fork.knife", "fork.knife.circle", "cup.and.saucer", "mug", "mug.fill",
        "refrigerator", "refrigerator.fill", "stove", "stove.fill", "oven",
        "oven.fill", "microwave", "microwave.fill", "dishwasher", "dishwasher.fill",
        // Storage & Organization
        "shippingbox", "shippingbox.fill", "archivebox", "archivebox.fill",
        "tray", "tray.fill", "tray.2", "tray.2.fill", "folder", "folder.fill",
        "cabinet", "cabinet.fill",
        // Security
        "lock", "lock.fill", "lock.open", "key", "key.fill", "bell", "bell.fill",
        "shield", "shield.fill", "camera", "camera.fill", "video", "video.fill",
        // Finance & Bills
        "creditcard", "creditcard.fill", "banknote", "banknote.fill", "cart",
        "cart.fill", "dollarsign.circle", "dollarsign.circle.fill",
        // Health & Safety
        "cross", "cross.fill", "cross.case", "cross.case.fill", "bandage", "bandage.fill",
        "smoke", "smoke.fill", "staroflife", "staroflife.fill",
        // Transport & Car
        "car", "car.fill", "car.2", "car.2.fill", "fuelpump", "fuelpump.fill",
        "wrench.adjustable", "wrench.adjustable.fill",
        // Technology
        "wifi", "network", "antenna.radiowaves.left.and.right", "tv", "tv.fill",
        "desktopcomputer", "laptopcomputer", "printer", "printer.fill",
        "phone", "phone.fill", "house.and.flag", "house.and.flag.fill",
        // Weather & Seasons
        "snowflake", "wind", "humidity", "thermometer.snowflake",
        "thermometer.sun.fill", "sun.and.horizon", "moon", "moon.fill",
        // Miscellaneous
        "star", "star.fill", "heart", "heart.fill", "checkmark.circle",
        "checkmark.circle.fill", "clock", "clock.fill", "calendar",
        "calendar.badge.plus", "person", "person.fill", "person.2", "person.2.fill",
        "note.text", "list.bullet", "checklist", "tag", "tag.fill",
        "flag", "flag.fill", "bookmark", "bookmark.fill", "mappin", "mappin.fill",
        "paintpalette", "paintpalette.fill", "hammer.circle", "hammer.circle.fill",
        "gear", "gearshape", "gearshape.fill", "gearshape.2", "gearshape.2.fill"
    ]
}
