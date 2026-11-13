import SwiftUI

struct TouchPoint: Identifiable, Codable {
    var id = UUID()
    var x: Double
    var y: Double
    var delay: Double = 0.2
    var duration: Double = 0.1
    var repeats: Int = 1
}

struct MacroProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var points: [TouchPoint] = []
    var loopForever = false
    var loopCount = 1
}

struct ContentView: View {
    @State private var profiles: [MacroProfile] = [
        MacroProfile(name: "Мій профіль")
    ]
    @State private var selectedID: UUID?
    @State private var recording = false
    @State private var profileName = ""
    @State private var showNameAlert = false

    private var selectedIndex: Int {
        profiles.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    private var selectedProfile: MacroProfile {
        profiles.isEmpty ? MacroProfile(name: "Мій профіль") : profiles[selectedIndex]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Профіль") {
                    Picker("Поточний профіль", selection: $selectedID) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    Button("Створити профіль") { showNameAlert = true }
                    Button("Зберегти зміни") { saveProfiles() }
                }

                Section("Поле координат") {
                    Text("Торкнися поля, щоб додати точку. Це записує координати лише всередині цієї програми.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.18))
                            Path { path in
                                for i in 1..<4 {
                                    let x = geo.size.width * CGFloat(i) / 4
                                    let y = geo.size.height * CGFloat(i) / 4
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                                }
                            }.stroke(.gray.opacity(0.35), lineWidth: 1)
                            ForEach(Array(selectedProfile.points.enumerated()), id: \.element.id) { index, point in
                                Circle()
                                    .fill(.cyan)
                                    .frame(width: 12, height: 12)
                                    .position(x: geo.size.width * point.x, y: geo.size.height * point.y)
                                Text("\\(index + 1)")
                                    .font(.caption2.bold())
                                    .position(x: geo.size.width * point.x + 12, y: geo.size.height * point.y - 12)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            addPoint(x: location.x / geo.size.width, y: location.y / geo.size.height)
                        }
                    }
                    .frame(height: 220)

                    Button(recording ? "Зупинити запис" : "Записати точки") {
                        recording.toggle()
                    }
                    .disabled(true)
                    Text("Запис дотиків у сторонніх програмах, зокрема Roblox, ця звичайна iOS-програма не підтримує.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Точки дотику") {
                    if selectedProfile.points.isEmpty {
                        Text("Поки немає точок. Додай їх на координатному полі.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(selectedProfile.points.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Точка \\(index + 1)").bold()
                                Spacer()
                                Button(role: .destructive) {
                                    updateProfile { $0.points.remove(at: index) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            HStack {
                                Text("Затримка")
                                Slider(value: bindingForPoint(index, keyPath: \.delay), in: 0...5, step: 0.1)
                                Text(String(format: "%.1f с", selectedProfile.points[index].delay))
                                    .monospacedDigit()
                            }
                            HStack {
                                Text("Тривалість")
                                Slider(value: bindingForPoint(index, keyPath: \.duration), in: 0.05...3, step: 0.05)
                                Text(String(format: "%.2f с", selectedProfile.points[index].duration))
                                    .monospacedDigit()
                            }
                            Stepper("Повторів: \\(selectedProfile.points[index].repeats)",
                                    value: bindingForPointInt(index), in: 1...100)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Повторення") {
                    Toggle("Нескінченний цикл", isOn: bindingForProfile(\.loopForever))
                    if !selectedProfile.loopForever {
                        Stepper("Кількість циклів: \\(selectedProfile.loopCount)",
                                value: bindingForProfileInt(\.loopCount), in: 1...999)
                    }
                    Text("Це налаштування зберігає сценарій. Виконання дотиків в інших програмах не реалізоване.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AutoTouch Pro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Зберегти") { saveProfiles() }
                }
            }
            .onAppear {
                loadProfiles()
                if selectedID == nil { selectedID = profiles.first?.id }
            }
            .alert("Новий профіль", isPresented: $showNameAlert) {
                TextField("Назва", text: $profileName)
                Button("Створити") {
                    let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let profile = MacroProfile(name: name.isEmpty ? "Новий профіль" : name)
                    profiles.append(profile)
                    selectedID = profile.id
                    profileName = ""
                    saveProfiles()
                }
                Button("Скасувати", role: .cancel) { profileName = "" }
            }
        }
    }

    private func addPoint(x: Double, y: Double) {
        updateProfile { $0.points.append(TouchPoint(x: x, y: y)) }
    }

    private func updateProfile(_ change: (inout MacroProfile) -> Void) {
        guard !profiles.isEmpty else { return }
        change(&profiles[selectedIndex])
    }

    private func bindingForProfile<T>(_ keyPath: WritableKeyPath<MacroProfile, T>) -> Binding<T> {
        Binding(get: { selectedProfile[keyPath: keyPath] },
                set: { value in updateProfile { $0[keyPath: keyPath] = value } })
    }

    private func bindingForProfileInt(_ keyPath: WritableKeyPath<MacroProfile, Int>) -> Binding<Int> {
        bindingForProfile(keyPath)
    }

    private func bindingForPoint(_ index: Int, keyPath: WritableKeyPath<TouchPoint, Double>) -> Binding<Double> {
        Binding(get: { selectedProfile.points[index][keyPath: keyPath] },
                set: { value in updateProfile { $0.points[index][keyPath: keyPath] = value } })
    }

    private func bindingForPointInt(_ index: Int) -> Binding<Int> {
        Binding(get: { selectedProfile.points[index].repeats },
                set: { value in updateProfile { $0.points[index].repeats = value } })
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "AutoTouchProProfiles")
        }
    }

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: "AutoTouchProProfiles"),
              let saved = try? JSONDecoder().decode([MacroProfile].self, from: data),
              !saved.isEmpty else { return }
        profiles = saved
        selectedID = profiles.first?.id
    }
}
