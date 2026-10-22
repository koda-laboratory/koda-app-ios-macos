import SwiftUI

/// Create or edit a product. Pushed for an existing product, presented as a sheet for a new one.
struct ProductEditorView: View {
    enum Presentation {
        case push
        case sheet
    }

    @State private var viewModel: ProductEditorViewModel
    let presentation: Presentation
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ProductEditorViewModel, presentation: Presentation = .push) {
        _viewModel = State(initialValue: viewModel)
        self.presentation = presentation
    }

    var body: some View {
        Form {
            Section {
                TextField("product-editor.name", text: $viewModel.form.name)
                    .accessibilityIdentifier("product-editor-name")
                if viewModel.showsNameError {
                    Text("product-editor.name.missing").font(KodaTypography.caption).foregroundStyle(KodaColor.error)
                }
                TextField("product-editor.emoji", text: $viewModel.form.emoji)
                Picker("product-editor.category", selection: $viewModel.form.category) {
                    ForEach(ProductCategory.allCases, id: \.self) { category in
                        Text(category.titleKey).tag(category)
                    }
                }
                TextField("product-editor.unit", text: $viewModel.form.defaultUnit)
            }

            Section("product-editor.stores") {
                if viewModel.stores.isEmpty {
                    Text("product-editor.stores.empty").foregroundStyle(KodaColor.textSecondary)
                }
                ForEach(viewModel.stores) { store in
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.form.storeIDs.contains(store.id) },
                            set: { _ in Task { await viewModel.send(.toggleStore(store.id)) } }
                        )
                    ) {
                        Text(verbatim: store.name)
                    }
                }
            }

            Section {
                LabeledContent("product-editor.price-per-kg") {
                    TextField("product-editor.price.placeholder", text: $viewModel.form.pricePerKgText)
                        .platformDecimalField()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("product-editor.price-total") {
                    TextField("product-editor.price.placeholder", text: $viewModel.form.priceTotalText)
                        .platformDecimalField()
                        .multilineTextAlignment(.trailing)
                }
                if viewModel.showsPriceError {
                    Text("product-editor.price.invalid").font(KodaTypography.caption).foregroundStyle(KodaColor.error)
                }
            } header: {
                Text("product-editor.prices")
            }

            if viewModel.isEditing {
                Section {
                    Button("product-editor.delete", role: .destructive) {
                        Task { await viewModel.send(.delete) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(KodaColor.background)
        .disabled(viewModel.state == .loading || viewModel.state == .missing)
        .navigationTitle(Text(viewModel.isEditing ? "product-editor.title.edit" : "product-editor.title.new"))
        .platformInlineNavigationTitle()
        .toolbar {
            if presentation == .sheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.save") { Task { await viewModel.send(.save) } }
                    .disabled(viewModel.state.isBusy)
                    .accessibilityIdentifier("product-editor-save")
            }
        }
        .dismissKeyboard()
        .keyboardMargin()
        .toast($viewModel.toast)
        .task { await viewModel.send(.appeared) }
        .onChange(of: viewModel.state) {
            if viewModel.state == .completed { dismiss() }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Product editor · edit") {
        NavigationStack {
            ProductsPreviewFactory.makeProductEditorView()
        }
        .kodaPreview()
    }

    #Preview("Product editor · new") {
        NavigationStack {
            ProductsPreviewFactory.makeProductEditorView(productID: nil)
        }
        .kodaPreview()
    }

    #Preview("Product editor · dark") {
        NavigationStack {
            ProductsPreviewFactory.makeProductEditorView()
        }
        .kodaPreview()
        .preferredColorScheme(.dark)
    }

    #Preview("Product editor · Mac", traits: .fixedLayout(width: 700, height: 700)) {
        NavigationStack {
            ProductsPreviewFactory.makeProductEditorView()
        }
        .kodaPreview()
    }
#endif
