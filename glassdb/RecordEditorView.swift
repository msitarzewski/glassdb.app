//
//  RecordEditorView.swift
//  glassdb
//
//  Full-screen modal for editing a single database row.
//  Staging model: edits highlighted, batched, applied on explicit save.
//

import SwiftUI
import GlassDBKit

// MARK: - Staged Edit Model

struct StagedEdit: Identifiable {
    let id = UUID()
    let columnIndex: Int
    let columnName: String
    let columnType: String
    let isPrimaryKey: Bool
    let isNullable: Bool
    let originalValue: DatabaseValue
    var editText: String
    var isNull: Bool

    var newValue: DatabaseValue {
        if isNull { return .null }
        return .string(editText)
    }

    var isModified: Bool {
        if isNull != originalValue.isNull { return true }
        if isNull { return false }
        return editText != originalValue.displayString
    }

    var typeLower: String { columnType.lowercased() }
    var isJSON: Bool { typeLower == "json" }
    var isLargeText: Bool { typeLower.contains("text") || typeLower.contains("blob") }
    var isBool: Bool { typeLower.contains("bool") || typeLower == "tinyint" }
}

// MARK: - Record Editor

struct RecordEditorView: View {
    enum RecordEditorMode {
        case edit(rowIndex: Int, originalRow: [DatabaseValue])
        case add
    }

    let columns: [ColumnInfo]
    let mode: RecordEditorMode
    let onSave: ([StagedEdit], RecordEditorMode) -> Void
    let onDiscard: () -> Void

    private var isAddMode: Bool {
        if case .add = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .edit(let rowIndex, _): return "Edit Row \(rowIndex + 1)"
        case .add: return "Add Row"
        }
    }

    @State private var edits: [StagedEdit] = []
    @State private var jsonErrors: [Int: String] = [:]

    private var hasChanges: Bool {
        edits.contains(where: \.isModified)
    }

    private var changeCount: Int {
        edits.filter(\.isModified).count
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(edits.enumerated()), id: \.element.id) { idx, edit in
                    fieldSection(edit: edit, index: idx)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDiscard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAddMode ? "Insert" : "Apply \(changeCount > 0 ? "(\(changeCount))" : "")") {
                        if isAddMode {
                            onSave(edits.filter { !$0.isNull }, mode)
                        } else {
                            onSave(edits.filter(\.isModified), mode)
                        }
                    }
                    .disabled(isAddMode ? jsonErrors.isEmpty == false : (!hasChanges || !jsonErrors.isEmpty))
                }
            }
        }
        .onAppear { initializeEdits() }
    }

    // MARK: - Field Section

    @ViewBuilder
    private func fieldSection(edit: StagedEdit, index: Int) -> some View {
        Section {
            if edit.isBool {
                boolField(edit: edit, index: index)
            } else if edit.isJSON {
                jsonField(edit: edit, index: index)
            } else if edit.isLargeText {
                largeTextField(edit: edit, index: index)
            } else {
                standardField(edit: edit, index: index)
            }

            // "Set to NULL" only — typing clears NULL automatically
            if edit.isNullable && !edit.isPrimaryKey && !edit.isNull {
                Button("Set to NULL", role: .destructive) {
                    edits[index].isNull = true
                    edits[index].editText = ""
                    jsonErrors.removeValue(forKey: index)
                }
                .font(.caption)
            }

            if let jsonErr = jsonErrors[index] {
                Label(jsonErr, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            HStack(spacing: 6) {
                Text(edit.columnName)
                if edit.isPrimaryKey {
                    Image(systemName: "key.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Text(edit.columnType)
                    .foregroundStyle(.secondary)
                Spacer()
                if edit.isModified {
                    Text("Modified")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Standard Field

    private func standardField(edit: StagedEdit, index: Int) -> some View {
        TextField(
            edit.columnName,
            text: fieldBinding(index: index),
            prompt: edit.isNull ? Text("NULL") : nil
        )
        .font(.system(.body, design: .monospaced))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(.asciiCapable)
    }

    // MARK: - Large Text Field

    private func largeTextField(edit: StagedEdit, index: Int) -> some View {
        TextField(
            edit.columnName,
            text: fieldBinding(index: index),
            prompt: edit.isNull ? Text("NULL") : nil,
            axis: .vertical
        )
        .font(.system(.body, design: .monospaced))
        .lineLimit(3...10)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(.asciiCapable)
    }

    // MARK: - Boolean Field

    private func boolField(edit: StagedEdit, index: Int) -> some View {
        Toggle(
            edit.isNull ? "NULL" : (edit.editText == "1" || edit.editText.lowercased() == "true" ? "true" : "false"),
            isOn: Binding(
                get: {
                    if edit.isNull { return false }
                    return edit.editText == "1" || edit.editText.lowercased() == "true"
                },
                set: { val in
                    edits[index].editText = val ? "1" : "0"
                    edits[index].isNull = false
                }
            )
        )
    }

    // MARK: - JSON Field

    @ViewBuilder
    private func jsonField(edit: StagedEdit, index: Int) -> some View {
        if edit.isNull {
            TextField(
                edit.columnName,
                text: fieldBinding(index: index),
                prompt: Text("NULL")
            )
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.asciiCapable)
        } else {
            TextEditor(text: fieldBinding(index: index))
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: 300)

            HStack {
                Button("Format") { formatJSON(index: index) }
                Button("Validate") { validateJSON(edits[index].editText, index: index) }
            }
            .font(.caption)
        }
    }

    // MARK: - Bindings

    private func fieldBinding(index: Int) -> Binding<String> {
        Binding(
            get: { edits[index].isNull ? "" : edits[index].editText },
            set: { newText in
                edits[index].editText = newText
                edits[index].isNull = false
            }
        )
    }

    // MARK: - JSON Helpers

    private func validateJSON(_ text: String, index: Int) {
        guard !text.isEmpty else {
            jsonErrors.removeValue(forKey: index)
            return
        }
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8))
            jsonErrors.removeValue(forKey: index)
        } catch {
            jsonErrors[index] = error.localizedDescription
        }
    }

    private func formatJSON(index: Int) {
        let text = edits[index].editText
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8) else {
            return
        }
        edits[index].editText = str
    }

    // MARK: - Init

    private func initializeEdits() {
        jsonErrors.removeAll()
        switch mode {
        case .edit(_, let originalRow):
            edits = columns.enumerated().map { colIndex, col in
                let value = colIndex < originalRow.count ? originalRow[colIndex] : .null
                return StagedEdit(
                    columnIndex: colIndex,
                    columnName: col.name,
                    columnType: col.type,
                    isPrimaryKey: col.isPrimaryKey,
                    isNullable: col.isNullable,
                    originalValue: value,
                    editText: value.isNull ? "" : value.displayString,
                    isNull: value.isNull
                )
            }
        case .add:
            edits = columns.enumerated().map { colIndex, col in
                StagedEdit(
                    columnIndex: colIndex,
                    columnName: col.name,
                    columnType: col.type,
                    isPrimaryKey: col.isPrimaryKey,
                    isNullable: col.isNullable,
                    originalValue: .null,
                    editText: "",
                    isNull: true
                )
            }
        }
    }
}
