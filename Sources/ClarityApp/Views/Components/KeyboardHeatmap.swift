import SwiftUI

/// Keyboard heatmap visualization showing key press frequency
struct KeyboardHeatmap: View {
    let keyData: [Int: Int]  // keyCode -> count
    var maxValue: Int {
        keyData.values.max() ?? 1
    }

    // Standard ANSI keyboard layout (rows of key codes)
    private let keyboardLayout: [[KeyInfo]] = [
        // Number row
        [
            KeyInfo(code: 50, label: "`", width: 1),
            KeyInfo(code: 18, label: "1", width: 1),
            KeyInfo(code: 19, label: "2", width: 1),
            KeyInfo(code: 20, label: "3", width: 1),
            KeyInfo(code: 21, label: "4", width: 1),
            KeyInfo(code: 23, label: "5", width: 1),
            KeyInfo(code: 22, label: "6", width: 1),
            KeyInfo(code: 26, label: "7", width: 1),
            KeyInfo(code: 28, label: "8", width: 1),
            KeyInfo(code: 25, label: "9", width: 1),
            KeyInfo(code: 29, label: "0", width: 1),
            KeyInfo(code: 27, label: "-", width: 1),
            KeyInfo(code: 24, label: "=", width: 1),
            KeyInfo(code: 51, label: "Delete", width: 1.5),
        ],
        // Tab row
        [
            KeyInfo(code: 48, label: "Tab", width: 1.5),
            KeyInfo(code: 12, label: "Q", width: 1),
            KeyInfo(code: 13, label: "W", width: 1),
            KeyInfo(code: 14, label: "E", width: 1),
            KeyInfo(code: 15, label: "R", width: 1),
            KeyInfo(code: 17, label: "T", width: 1),
            KeyInfo(code: 16, label: "Y", width: 1),
            KeyInfo(code: 32, label: "U", width: 1),
            KeyInfo(code: 34, label: "I", width: 1),
            KeyInfo(code: 31, label: "O", width: 1),
            KeyInfo(code: 35, label: "P", width: 1),
            KeyInfo(code: 33, label: "[", width: 1),
            KeyInfo(code: 30, label: "]", width: 1),
            KeyInfo(code: 42, label: "\\", width: 1),
        ],
        // Caps row
        [
            KeyInfo(code: 57, label: "Caps", width: 1.75),
            KeyInfo(code: 0, label: "A", width: 1),
            KeyInfo(code: 1, label: "S", width: 1),
            KeyInfo(code: 2, label: "D", width: 1),
            KeyInfo(code: 3, label: "F", width: 1),
            KeyInfo(code: 5, label: "G", width: 1),
            KeyInfo(code: 4, label: "H", width: 1),
            KeyInfo(code: 38, label: "J", width: 1),
            KeyInfo(code: 40, label: "K", width: 1),
            KeyInfo(code: 37, label: "L", width: 1),
            KeyInfo(code: 41, label: ";", width: 1),
            KeyInfo(code: 39, label: "'", width: 1),
            KeyInfo(code: 36, label: "Return", width: 1.75),
        ],
        // Shift row
        [
            KeyInfo(code: 56, label: "Shift", width: 2.25),
            KeyInfo(code: 6, label: "Z", width: 1),
            KeyInfo(code: 7, label: "X", width: 1),
            KeyInfo(code: 8, label: "C", width: 1),
            KeyInfo(code: 9, label: "V", width: 1),
            KeyInfo(code: 11, label: "B", width: 1),
            KeyInfo(code: 45, label: "N", width: 1),
            KeyInfo(code: 46, label: "M", width: 1),
            KeyInfo(code: 43, label: ",", width: 1),
            KeyInfo(code: 47, label: ".", width: 1),
            KeyInfo(code: 44, label: "/", width: 1),
            KeyInfo(code: 60, label: "Shift", width: 2.25),
        ],
        // Bottom row
        [
            KeyInfo(code: 59, label: "Ctrl", width: 1.25),
            KeyInfo(code: 58, label: "Opt", width: 1.25),
            KeyInfo(code: 55, label: "Cmd", width: 1.5),
            KeyInfo(code: 49, label: "Space", width: 6),
            KeyInfo(code: 54, label: "Cmd", width: 1.5),
            KeyInfo(code: 61, label: "Opt", width: 1.25),
            KeyInfo(code: 62, label: "Ctrl", width: 1.25),
        ],
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(keyboardLayout.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row) { key in
                        KeyView(
                            key: key,
                            count: keyData[key.code] ?? 0,
                            maxValue: maxValue
                        )
                    }
                }
            }
        }
        .padding(ClaritySpacing.md)
        .background(ClarityColors.backgroundSecondary)
        .cornerRadius(ClarityRadius.lg)
    }
}

// MARK: - Key Info

struct KeyInfo: Identifiable {
    let id = UUID()
    let code: Int
    let label: String
    let width: CGFloat

    init(code: Int, label: String, width: CGFloat = 1) {
        self.code = code
        self.label = label
        self.width = width
    }
}

// MARK: - Key View

struct KeyView: View {
    let key: KeyInfo
    let count: Int
    let maxValue: Int

    private let baseSize: CGFloat = 36

    var intensity: Double {
        guard maxValue > 0 else { return 0 }
        return Double(count) / Double(maxValue)
    }

    var keyColor: Color {
        if count == 0 {
            return ClarityColors.backgroundTertiary
        }
        // Gradient from light blue to deep blue based on intensity
        let hue: Double = 0.6  // Blue hue
        let saturation: Double = 0.3 + (intensity * 0.5)
        let brightness: Double = 0.95 - (intensity * 0.3)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var textColor: Color {
        if intensity > 0.5 {
            return .white
        }
        return ClarityColors.textPrimary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(keyColor)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)

            VStack(spacing: 2) {
                Text(key.label)
                    .font(.system(size: key.width > 1.5 ? 10 : 12, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if count > 0 {
                    Text(formatCount(count))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.8))
                }
            }
        }
        .frame(width: baseSize * key.width + (key.width - 1) * 4, height: baseSize)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}

// MARK: - Preview

#Preview {
    // Sample data showing typical typing patterns
    let sampleData: [Int: Int] = [
        // High frequency (common letters)
        14: 1500,  // E
        17: 1200,  // T
        0: 1100,   // A
        31: 1000,  // O
        34: 950,   // I
        45: 900,   // N
        1: 850,    // S
        4: 800,    // H
        15: 750,   // R
        2: 700,    // D
        37: 650,   // L
        8: 600,    // C

        // Medium frequency
        32: 500,   // U
        46: 450,   // M
        13: 400,   // W
        3: 350,    // F
        5: 300,    // G
        16: 280,   // Y
        35: 250,   // P
        11: 220,   // B
        9: 200,    // V
        40: 180,   // K

        // Low frequency
        38: 100,   // J
        7: 80,     // X
        12: 60,    // Q
        6: 40,     // Z

        // Special keys
        49: 2000,  // Space
        51: 300,   // Delete
        36: 400,   // Return
        48: 150,   // Tab
        56: 200,   // Shift
    ]

    KeyboardHeatmap(keyData: sampleData)
        .padding()
        .background(ClarityColors.backgroundPrimary)
        .frame(width: 700)
}
