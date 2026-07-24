import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

@MainActor
struct LogFoodSheet: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mealType: MealType = .lunch
    @State private var searchText = ""
    @State private var note = ""
    @State private var items: [EditableMealItem] = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var showCamera = false
    @State private var showBarcodeScanner = false
    @State private var isAnalyzing = false
    @State private var analysisTitle = ""
    @State private var analysisOverview = ""
    @State private var analysisSource: MealAnalysisSource = .manual
    @State private var errorMessage: String?
    @State private var loggedAt: Date
    @State private var saveAsSingleMeal = true
    let date: Date
    let editingLog: FoodLog?

    init(date: Date = .now, editingLog: FoodLog? = nil) {
        self.date = date
        self.editingLog = editingLog
        _loggedAt = State(initialValue: editingLog?.date ?? date)
        _mealType = State(initialValue: editingLog?.meal ?? .lunch)
        _note = State(initialValue: editingLog?.note ?? "")
        if let editingLog {
            _analysisTitle = State(initialValue: editingLog.name)
            _analysisOverview = State(initialValue: "Review and update this saved nutrition entry.")
            _analysisSource = State(initialValue: .manual)
            _items = State(initialValue: [EditableMealItem(log: editingLog)])
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PeakTheme.Spacing.lg) {
                    aiSearchCard
                    captureMethods
                    if isAnalyzing { analyzingCard }
                    if let errorMessage { errorCard(errorMessage) }
                    if !items.isEmpty { editableResult }
                    else if !isAnalyzing { quickSuggestions }
                    privacyNote
                }
                .padding(PeakTheme.Spacing.md)
                .padding(.bottom, PeakTheme.Spacing.xl)
            }
            .peakDismissKeyboardOnSwipe()
            .peakScreenBackground()
            .navigationTitle(editingLog == nil ? "AI Meal Log" : "Edit Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingLog == nil ? "Save Meal" : "Update") { save() }
                        .disabled(items.isEmpty || items.allSatisfy { $0.name.trimmed.isEmpty })
                }
            }
            .sheet(isPresented: $showCamera) {
                MealCameraPicker { image in
                    showCamera = false
                    guard let image, let data = image.peakMealJPEG else { return }
                    previewImage = image
                    Task { await analyze(.init(imageData: data, source: .photo)) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerSheet { barcode in
                    showBarcodeScanner = false
                    Task { await lookupBarcode(barcode) }
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    guard let data = try? await photo.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let jpeg = image.peakMealJPEG else { return }
                    previewImage = image
                    await analyze(.init(imageData: jpeg, source: .photo))
                }
            }
        }
    }

    private var aiSearchCard: some View {
        PeakCard {
            VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
                HStack {
                    ZStack {
                        Circle().fill(PeakTheme.ultraviolet.opacity(0.13))
                        Image(systemName: "sparkles")
                            .foregroundStyle(PeakTheme.ultraviolet)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Describe or search a meal")
                            .font(PeakTheme.Typography.headline)
                        Text("Peak AI builds an editable nutrition estimate")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                HStack(spacing: PeakTheme.Spacing.sm) {
                    TextField("e.g. chicken burrito bowl", text: $searchText)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.search)
                        .onSubmit { analyzeSearch() }
                    Button { analyzeSearch() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(PeakTheme.accent)
                    }
                    .disabled(searchText.trimmed.isEmpty || isAnalyzing)
                    .accessibilityLabel("Analyze meal description")
                }
                .padding(.horizontal, PeakTheme.Spacing.sm)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.accent.opacity(0.05))
            }
        }
    }

    private var captureMethods: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Capture Meal", icon: "viewfinder")
            HStack(spacing: PeakTheme.Spacing.sm) {
                captureButton("Camera", icon: "camera.fill", color: PeakTheme.coral, enabled: UIImagePickerController.isSourceTypeAvailable(.camera)) {
                    showCamera = true
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    MealCaptureLabel(title: "Photo", icon: "photo.fill", color: PeakTheme.lavender)
                }
                .buttonStyle(.plain)
                captureButton("Barcode", icon: "barcode.viewfinder", color: PeakTheme.mint, enabled: DataScannerViewController.isSupported && DataScannerViewController.isAvailable) {
                    showBarcodeScanner = true
                }
                captureButton("Manual", icon: "square.and.pencil", color: PeakTheme.gold) {
                    analysisSource = .manual
                    analysisTitle = "Manual meal"
                    analysisOverview = "Enter the label or portion values you know."
                    items.append(EditableMealItem())
                }
            }

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: PeakTheme.Radius.lg))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.previewImage = nil
                            selectedPhoto = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.45))
                        }
                        .padding(8)
                    }
            }
        }
    }

    private func captureButton(
        _ title: String,
        icon: String,
        color: Color,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { MealCaptureLabel(title: title, icon: icon, color: color) }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
    }

}

private struct MealCaptureLabel: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(title).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PeakTheme.Spacing.sm)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: color.opacity(0.07), interactive: true)
    }
}

@MainActor
private extension LogFoodSheet {
    private var analyzingCard: some View {
        PeakCard {
            HStack(spacing: PeakTheme.Spacing.md) {
                ProgressView().tint(PeakTheme.ultraviolet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analyzing your meal…").font(PeakTheme.Typography.headline)
                    Text("Identifying foods, portions, calories, and macros")
                        .font(PeakTheme.Typography.micro)
                        .foregroundStyle(PeakTheme.textSecondary)
                }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: PeakTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PeakTheme.gold)
            Text(message).font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
            Spacer()
            Button { errorMessage = nil } label: { Image(systemName: "xmark") }
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.gold.opacity(0.08))
    }

    private var editableResult: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(analysisTitle.isEmpty ? "Meal details" : analysisTitle, systemImage: sourceIcon)
                        .font(PeakTheme.Typography.headline)
                    if !analysisOverview.isEmpty {
                        Text(analysisOverview)
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
                Spacer()
                confidenceBadge
            }

            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)

            PeakCard {
                VStack(spacing: PeakTheme.Spacing.sm) {
                    DatePicker("Meal time", selection: $loggedAt)
                    if editingLog == nil, items.count > 1 {
                        Toggle("Save foods together as one meal", isOn: $saveAsSingleMeal)
                        Text(saveAsSingleMeal
                             ? "Ingredients and nutrition will be combined into one editable meal."
                             : "Each identified food will be saved as its own entry.")
                            .font(PeakTheme.Typography.micro)
                            .foregroundStyle(PeakTheme.textSecondary)
                    }
                }
            }

            ForEach($items) { $item in
                editableFoodCard(item: $item)
            }

            Button {
                items.append(EditableMealItem())
                PeakHaptics.selection()
            } label: {
                Label("Add another food", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            PeakCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Meal total").font(PeakTheme.Typography.caption).foregroundStyle(PeakTheme.textSecondary)
                        Text("\(totalCalories) kcal").font(PeakTheme.Typography.title)
                    }
                    Spacer()
                    macroTotal("P", totalProtein, PeakTheme.coral)
                    macroTotal("C", totalCarbs, PeakTheme.gold)
                    macroTotal("F", totalFat, PeakTheme.lavender)
                }
            }

            TextField("Optional meal note", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(PeakTheme.Spacing.md)
                .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.accent.opacity(0.035))
        }
    }

    private func editableFoodCard(item: Binding<EditableMealItem>) -> some View {
        let color = PeakTheme.gold
        return VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            HStack {
                Image(systemName: "fork.knife").foregroundStyle(color)
                TextField("Food name", text: item.name)
                    .font(PeakTheme.Typography.headline)
                Button(role: .destructive) {
                    items.removeAll { $0.id == item.wrappedValue.id }
                } label: { Image(systemName: "trash") }
            }
            TextField("Serving or portion", text: item.serving)
                .font(PeakTheme.Typography.caption)

            HStack(spacing: PeakTheme.Spacing.sm) {
                editableNumber("Calories", value: item.calories, unit: "kcal")
                editableNumber("Protein", value: item.proteinG, unit: "g")
            }
            HStack(spacing: PeakTheme.Spacing.sm) {
                editableNumber("Carbs", value: item.carbsG, unit: "g")
                editableNumber("Fat", value: item.fatG, unit: "g")
            }
            DisclosureGroup("Complete nutrition details") {
                VStack(spacing: PeakTheme.Spacing.sm) {
                    HStack(spacing: PeakTheme.Spacing.sm) {
                        editableNumber("Fiber", value: item.fiberG, unit: "g")
                        editableNumber("Sugar", value: item.sugarG, unit: "g")
                    }
                    HStack(spacing: PeakTheme.Spacing.sm) {
                        editableNumber("Saturated fat", value: item.saturatedFatG, unit: "g")
                        editableNumber("Sodium", value: item.sodiumMg, unit: "mg")
                    }
                    editableNumber("Cholesterol", value: item.cholesterolMg, unit: "mg")
                    TextField(
                        "Ingredients, separated by commas",
                        text: item.ingredients,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                    .padding(PeakTheme.Spacing.sm)
                    .background(
                        PeakTheme.surface.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: PeakTheme.Radius.sm)
                    )
                }
                .padding(.top, PeakTheme.Spacing.xs)
            }
            .font(PeakTheme.Typography.caption)
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.lg, tint: color.opacity(0.055))
    }

    private func editableNumber(_ title: String, value: Binding<Int>, unit: String) -> some View {
        nutritionField(title, unit: unit) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func editableNumber(_ title: String, value: Binding<Double>, unit: String) -> some View {
        nutritionField(title, unit: unit) {
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func nutritionField<Content: View>(_ title: String, unit: String, @ViewBuilder field: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary)
            HStack(spacing: 3) {
                field()
                Text(unit).font(PeakTheme.Typography.micro).foregroundStyle(PeakTheme.textSecondary)
            }
        }
        .padding(PeakTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(PeakTheme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: PeakTheme.Radius.sm))
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: PeakTheme.Spacing.sm) {
            SectionHeaderView(title: "Common Foods", icon: "clock.arrow.circlepath")
            ForEach(FoodPresets.common, id: \.name) { preset in
                Button {
                    analysisSource = .search
                    analysisTitle = preset.name
                    analysisOverview = "Saved common-food estimate — review the portion before saving."
                    items = [EditableMealItem(preset: preset)]
                    PeakHaptics.selection()
                } label: {
                    HStack {
                        Text(preset.name).foregroundStyle(PeakTheme.textPrimary)
                        Spacer()
                        Text("\(preset.cal) kcal")
                            .font(PeakTheme.Typography.caption)
                            .foregroundStyle(PeakTheme.textSecondary)
                        Image(systemName: "plus.circle.fill").foregroundStyle(PeakTheme.accent)
                    }
                    .padding(PeakTheme.Spacing.sm)
                    .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.gold.opacity(0.035), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Private by design", systemImage: "lock.shield.fill")
                .font(PeakTheme.Typography.caption).fontWeight(.semibold)
            Text("Search descriptions and selected meal photos are sent to OpenAI only when you choose an AI action. Barcode nutrition comes from Open Food Facts. AI and community food data can be inaccurate, so Peak always lets you review every value before saving.")
                .font(PeakTheme.Typography.micro)
                .foregroundStyle(PeakTheme.textSecondary)
        }
        .padding(PeakTheme.Spacing.md)
        .glassCard(cornerRadius: PeakTheme.Radius.md, tint: PeakTheme.mint.opacity(0.04))
    }

    private var sourceIcon: String {
        switch analysisSource {
        case .search: "text.magnifyingglass"
        case .photo: "camera.fill"
        case .barcode: "barcode.viewfinder"
        case .manual: "square.and.pencil"
        }
    }

    private var confidenceBadge: some View {
        let confidence = items.map(\.confidence).reduce(0, +) / Double(max(items.count, 1))
        return Text(analysisSource == .manual ? "Manual" : "\(Int(confidence * 100))% match")
            .font(PeakTheme.Typography.micro)
            .foregroundStyle(confidence >= 0.8 ? PeakTheme.mint : PeakTheme.gold)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .glassCapsule(tint: (confidence >= 0.8 ? PeakTheme.mint : PeakTheme.gold).opacity(0.08))
    }

    private func macroTotal(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(PeakTheme.Typography.micro).foregroundStyle(color)
            Text("\(Int(value.rounded()))g").font(PeakTheme.Typography.caption).fontWeight(.semibold)
        }
    }

    private var totalCalories: Int { items.reduce(0) { $0 + max(0, $1.calories) } }
    private var totalProtein: Double { items.reduce(0) { $0 + max(0, $1.proteinG) } }
    private var totalCarbs: Double { items.reduce(0) { $0 + max(0, $1.carbsG) } }
    private var totalFat: Double { items.reduce(0) { $0 + max(0, $1.fatG) } }
    private var totalFiber: Double { items.reduce(0) { $0 + max(0, $1.fiberG) } }
    private var totalSugar: Double { items.reduce(0) { $0 + max(0, $1.sugarG) } }
    private var totalSaturatedFat: Double { items.reduce(0) { $0 + max(0, $1.saturatedFatG) } }
    private var totalSodium: Double { items.reduce(0) { $0 + max(0, $1.sodiumMg) } }
    private var totalCholesterol: Double { items.reduce(0) { $0 + max(0, $1.cholesterolMg) } }

    private func analyzeSearch() {
        guard !searchText.trimmed.isEmpty else { return }
        let query = searchText.trimmed
        if let preset = FoodPresets.common.first(where: { $0.name.localizedCaseInsensitiveContains(query) || query.localizedCaseInsensitiveContains($0.name) }) {
            analysisSource = .search
            analysisTitle = preset.name
            analysisOverview = "Matched a common food. Review the serving and nutrition below."
            items = [EditableMealItem(preset: preset)]
            return
        }
        Task { await analyze(.init(query: query, source: .search)) }
    }

    private func analyze(_ request: MealAnalysisRequest) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            let result = try await container.ai.analyzeMeal(request)
            analysisSource = result.source
            analysisTitle = result.title
            analysisOverview = result.overview
            items = result.items.map(EditableMealItem.init)
            PeakHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            if request.source == .search, let query = request.query, items.isEmpty {
                analysisSource = .manual
                analysisTitle = query
                analysisOverview = "AI is unavailable. Enter the nutrition values you know, or add an OpenAI key in Settings."
                items = [EditableMealItem(name: query)]
            }
        }
    }

    private func lookupBarcode(_ barcode: String) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            let item = try await OpenFoodFactsLookup.lookup(barcode: barcode)
            analysisSource = .barcode
            analysisTitle = item.name
            analysisOverview = "Product-label nutrition from Open Food Facts. Confirm the serving size on the package."
            items = [EditableMealItem(item)]
            PeakHaptics.success()
        } catch {
            analysisSource = .manual
            analysisTitle = "Barcode \(barcode)"
            analysisOverview = "Product not found. Add the package details manually."
            items = [EditableMealItem(name: "", serving: "1 serving")]
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        if let editingLog {
            editingLog.name = items.count == 1
                ? items[0].name.trimmed
                : (analysisTitle.trimmed.isEmpty ? "Custom Meal" : analysisTitle.trimmed)
            editingLog.mealType = mealType.rawValue
            editingLog.calories = totalCalories
            editingLog.proteinG = totalProtein
            editingLog.carbsG = totalCarbs
            editingLog.fatG = totalFat
            editingLog.fiberG = totalFiber
            editingLog.sugarG = totalSugar
            editingLog.saturatedFatG = totalSaturatedFat
            editingLog.sodiumMg = totalSodium
            editingLog.cholesterolMg = totalCholesterol
            editingLog.servingSize = combinedServing
            editingLog.ingredients = combinedIngredients
            editingLog.note = note.trimmed.isEmpty ? nil : note.trimmed
            editingLog.date = loggedAt
            finishSave()
            return
        }

        if saveAsSingleMeal, items.count > 1 {
            modelContext.insert(FoodLog(
                name: analysisTitle.trimmed.isEmpty ? "Custom Meal" : analysisTitle.trimmed,
                mealType: mealType,
                calories: totalCalories,
                proteinG: totalProtein,
                carbsG: totalCarbs,
                fatG: totalFat,
                fiberG: totalFiber,
                sugarG: totalSugar,
                saturatedFatG: totalSaturatedFat,
                sodiumMg: totalSodium,
                cholesterolMg: totalCholesterol,
                servingSize: combinedServing,
                ingredients: combinedIngredients,
                note: note.trimmed.isEmpty ? nil : note.trimmed,
                date: loggedAt
            ))
            finishSave()
            return
        }

        for item in items where !item.name.trimmed.isEmpty {
            modelContext.insert(FoodLog(
                name: item.name.trimmed,
                mealType: mealType,
                calories: max(0, item.calories),
                proteinG: max(0, item.proteinG),
                carbsG: max(0, item.carbsG),
                fatG: max(0, item.fatG),
                fiberG: max(0, item.fiberG),
                sugarG: max(0, item.sugarG),
                saturatedFatG: max(0, item.saturatedFatG),
                sodiumMg: max(0, item.sodiumMg),
                cholesterolMg: max(0, item.cholesterolMg),
                servingSize: item.serving.trimmed.isEmpty ? nil : item.serving.trimmed,
                ingredients: item.ingredients.trimmed,
                note: note.trimmed.isEmpty ? nil : note.trimmed,
                date: loggedAt
            ))
        }
        finishSave()
    }

    private var combinedServing: String? {
        let servings = items.map(\.serving).map(\.trimmed).filter { !$0.isEmpty }
        return servings.isEmpty ? nil : servings.joined(separator: " + ")
    }

    private var combinedIngredients: String {
        var seen = Set<String>()
        return items.flatMap { item in
            let listed = item.ingredients
                .split(separator: ",")
                .map { String($0).trimmed }
                .filter { !$0.isEmpty }
            return listed.isEmpty ? [item.name.trimmed] : listed
        }
        .filter { !$0.isEmpty }
        .filter { seen.insert($0.lowercased()).inserted }
        .joined(separator: ", ")
    }

    private func finishSave() {
        try? modelContext.save()
        AchievementService.evaluateAll(modelContext: modelContext)
        PeakHaptics.success()
        dismiss()
    }
}

private struct EditableMealItem: Identifiable {
    var id = UUID()
    var name = ""
    var serving = "1 serving"
    var calories = 0
    var proteinG = 0.0
    var carbsG = 0.0
    var fatG = 0.0
    var fiberG = 0.0
    var sugarG = 0.0
    var saturatedFatG = 0.0
    var sodiumMg = 0.0
    var cholesterolMg = 0.0
    var ingredients = ""
    var confidence = 1.0

    init(
        name: String = "",
        serving: String = "1 serving",
        calories: Int = 0,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        sugarG: Double = 0,
        saturatedFatG: Double = 0,
        sodiumMg: Double = 0,
        cholesterolMg: Double = 0,
        ingredients: String = "",
        confidence: Double = 1
    ) {
        self.name = name
        self.serving = serving
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.saturatedFatG = saturatedFatG
        self.sodiumMg = sodiumMg
        self.cholesterolMg = cholesterolMg
        self.ingredients = ingredients
        self.confidence = confidence
    }

    init(_ item: MealAnalysisItem) {
        self.init(
            name: item.name,
            serving: item.serving,
            calories: item.calories,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
            fiberG: item.fiberG,
            sugarG: item.sugarG,
            saturatedFatG: item.saturatedFatG,
            sodiumMg: item.sodiumMg,
            cholesterolMg: item.cholesterolMg,
            ingredients: item.ingredients.joined(separator: ", "),
            confidence: item.confidence
        )
    }

    init(log: FoodLog) {
        self.init(
            name: log.name,
            serving: log.servingSize ?? "1 serving",
            calories: log.calories,
            proteinG: log.proteinG,
            carbsG: log.carbsG,
            fatG: log.fatG,
            fiberG: log.fiberG,
            sugarG: log.sugarG,
            saturatedFatG: log.saturatedFatG,
            sodiumMg: log.sodiumMg,
            cholesterolMg: log.cholesterolMg,
            ingredients: log.ingredients
        )
    }

    init(preset: (name: String, cal: Int, protein: Double, carbs: Double, fat: Double)) {
        self.init(
            name: preset.name,
            calories: preset.cal,
            proteinG: preset.protein,
            carbsG: preset.carbs,
            fatG: preset.fat,
            confidence: 0.82
        )
    }
}

private enum OpenFoodFactsLookup {
    struct Envelope: Decodable {
        struct Product: Decodable {
            struct Nutriments: Decodable {
                let caloriesServing: Double?
                let calories100g: Double?
                let proteinServing: Double?
                let protein100g: Double?
                let carbsServing: Double?
                let carbs100g: Double?
                let fatServing: Double?
                let fat100g: Double?

                enum CodingKeys: String, CodingKey {
                    case caloriesServing = "energy-kcal_serving"
                    case calories100g = "energy-kcal_100g"
                    case proteinServing = "proteins_serving"
                    case protein100g = "proteins_100g"
                    case carbsServing = "carbohydrates_serving"
                    case carbs100g = "carbohydrates_100g"
                    case fatServing = "fat_serving"
                    case fat100g = "fat_100g"
                }
            }

            let productName: String?
            let brands: String?
            let servingSize: String?
            let nutriments: Nutriments?

            enum CodingKeys: String, CodingKey {
                case productName = "product_name"
                case brands
                case servingSize = "serving_size"
                case nutriments
            }
        }
        let product: Product?
    }

    static func lookup(barcode: String) async throws -> MealAnalysisItem {
        let normalized = barcode.filter(\.isNumber)
        guard normalized.count >= 8,
              var components = URLComponents(string: "https://world.openfoodfacts.org/api/v3/product/\(normalized).json") else {
            throw PeakError.invalidInput("That barcode could not be read.")
        }
        components.queryItems = [URLQueryItem(name: "fields", value: "product_name,brands,serving_size,nutriments")]
        guard let url = components.url else { throw PeakError.invalidInput("That barcode could not be read.") }
        var request = URLRequest(url: url)
        request.setValue("Peak Health - iOS - 0.2.0 - barcode scan", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PeakError.invalidInput("No product was found for that barcode.")
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: data)
        guard let product = decoded.product,
              let name = product.productName?.trimmed,
              !name.isEmpty else {
            throw PeakError.invalidInput("No product was found for that barcode.")
        }
        let n = product.nutriments
        let hasServing = n?.caloriesServing != nil || n?.proteinServing != nil
        return MealAnalysisItem(
            name: product.brands?.isEmpty == false ? "\(product.brands!) \(name)" : name,
            serving: hasServing ? (product.servingSize ?? "1 serving") : "100 g",
            calories: Int((n?.caloriesServing ?? n?.calories100g ?? 0).rounded()),
            proteinG: n?.proteinServing ?? n?.protein100g ?? 0,
            carbsG: n?.carbsServing ?? n?.carbs100g ?? 0,
            fatG: n?.fatServing ?? n?.fat100g ?? 0,
            confidence: 0.98
        )
    }
}

private struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onBarcode: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                BarcodeScannerView(onBarcode: onBarcode)
                    .ignoresSafeArea()
                Text("Center the product barcode in view")
                    .font(PeakTheme.Typography.caption).fontWeight(.semibold)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassCapsule(tint: PeakTheme.midnight.opacity(0.15))
                    .padding(.bottom, 24)
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onBarcode: onBarcode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        private var delivered = false

        init(onBarcode: @escaping (String) -> Void) { self.onBarcode = onBarcode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                    delivered = true
                    dataScanner.stopScanning()
                    onBarcode(value)
                    return
                }
            }
        }
    }
}

private struct MealCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onImage(nil) }
    }
}

private extension UIImage {
    var peakMealJPEG: Data? {
        let maxDimension: CGFloat = 1600
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.78)
    }
}
