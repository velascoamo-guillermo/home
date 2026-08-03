import SwiftUI

struct OutOfStockInfo: Identifiable {
    let id = UUID()
    let product: StockProduct
    let needed: Int
}

extension View {
    func outOfStockAlert(_ info: Binding<OutOfStockInfo?>) -> some View {
        alert("Out of stock",
              isPresented: Binding(
                  get: { info.wrappedValue != nil },
                  set: { if !$0 { info.wrappedValue = nil } }
              ),
              presenting: info.wrappedValue) { _ in
            Button("OK", role: .cancel) { }
        } message: { i in
            Text("Needs \(i.needed), only \(i.product.totalUnits) left. Restock \(i.product.name) — the task was marked done anyway.")
        }
    }
}
