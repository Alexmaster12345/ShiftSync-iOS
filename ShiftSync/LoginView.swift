import SwiftUI

struct LoginView: View {
    let onLoginSuccess: (String) -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: min(64, h * 0.096))

                    // Logo
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.shiftBlue, Color.shiftBlueDark],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: min(96, h * 0.14), height: min(96, h * 0.14))
                            .shadow(color: Color.shiftBlue.opacity(0.35), radius: 16, y: 8)
                        Image(systemName: "clock.fill")
                            .font(.system(size: min(42, h * 0.063), weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer().frame(height: min(24, h * 0.036))

                    Text("ShiftSync")
                        .font(.system(size: min(32, h * 0.048), weight: .black))
                        .foregroundColor(.ssTextPrimary)

                    Spacer().frame(height: min(8, h * 0.012))

                    Text("Track your hours, sync with your life.\nSimple & automatic.")
                        .font(.system(size: 15))
                        .foregroundColor(.ssTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Spacer().frame(height: min(48, h * 0.072))

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your name?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.ssTextPrimary)

                        HStack(spacing: 10) {
                            Image(systemName: "person")
                                .foregroundColor(.ssTextMuted)
                                .font(.system(size: 15))
                            TextField("e.g. Alex Johnson", text: $name)
                                .font(.system(size: 15))
                                .foregroundColor(.ssTextPrimary)
                                .disableAutocorrection(true)
                                .focused($nameFocused)
                                .submitLabel(.go)
                                .onSubmit { continueAsGuest() }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(nameFocused ? Color.shiftBlue.opacity(0.7) : Color.clear, lineWidth: 1.5)
                        )

                        Text("Optional — you can update this later in your profile.")
                            .font(.system(size: 12))
                            .foregroundColor(.ssTextMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: min(28, h * 0.042))

                    // Primary CTA
                    Button(action: continueAsGuest) {
                        Text("Continue as Guest")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.shiftBlue)
                            .clipShape(Capsule())
                            .shadow(color: Color.shiftBlue.opacity(0.3), radius: 8, y: 4)
                    }

                    Spacer().frame(height: min(20, h * 0.030))

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(Color(UIColor.separator)).frame(height: 1)
                        Text("or")
                            .font(.system(size: 13))
                            .foregroundColor(.ssTextMuted)
                            .fixedSize()
                        Rectangle().fill(Color(UIColor.separator)).frame(height: 1)
                    }

                    Spacer().frame(height: min(20, h * 0.030))

                    // Secondary — coming soon
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope")
                                .font(.system(size: 14))
                            Text("Sign In with Email")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Coming Soon")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.shiftBlue.opacity(0.65))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(.ssTextMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                    .disabled(true)

                    Spacer().frame(height: min(48, h * 0.072))
                }
                .padding(.horizontal, 28)
                .frame(minHeight: proxy.size.height)
            }
        }
        .background(Color.darkBg.ignoresSafeArea())
    }

    private func continueAsGuest() {
        nameFocused = false
        let display = name.trimmingCharacters(in: .whitespaces)
        onLoginSuccess(display.isEmpty ? "Guest" : display)
    }
}

#Preview {
    LoginView { _ in }
}
