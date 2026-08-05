import SwiftUI

struct OutOfStockInfo: Identifiable {
    let id = UUID()
    let product: StockProduct
    let needed: Int
}

extension View {
    func outOfStockAlert(_ info: Binding<OutOfStockInfo?>) -> some View {
        modifier(OutOfStockAlertModifier(info: info))
    }
}

private struct OutOfStockAlertModifier: ViewModifier {
    @Binding var info: OutOfStockInfo?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("Out of stock",
                      isPresented: Binding(
                          get: { info != nil },
                          set: { if !$0 { info = nil } }
                      ),
                      presenting: info) { _ in
            Button("View Shopping") {
                openURL(URL(string: "home://shopping")!)
            }
            Button("OK", role: .cancel) { }
        } message: { i in
            Text("Needs \(i.needed), only \(i.product.totalUnits) left. Restock \(i.product.name) — the task was marked done anyway.")
        }
    }
}
