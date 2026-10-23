import SwiftUI

/// Uygulamanın ana görünümü. VideoAsistan çalışma zamanında üç hâlde geçer:
/// boş (sürükle-bırak), işlem sürüyor ve sonuçlar hazır.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("VideoAsistan")
                .font(.title2.weight(.semibold))
            Text("Video döküp altyazı, bölüm ve YouTube metinleri hazırlanıyor.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 640, minHeight: 420)
    }
}
