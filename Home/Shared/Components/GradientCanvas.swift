import SwiftUI

nonisolated enum GradientCanvas {
    static var fill: LinearGradient {
        LinearGradient(colors: [Palette.canvasTop, Palette.canvasMid, Palette.canvasBottom],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func gradientCanvas() -> some View {
        background(GradientCanvas.fill.ignoresSafeArea())
    }
}
