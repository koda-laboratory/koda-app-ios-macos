# Fix Patterns

Concrete before/after examples for approved fixes. Treat values as examples, not automatic recommendations. For source changes, follow [swiftui-expert-skill](../../swiftui-expert-skill/SKILL.md), [swift-concurrency](../../swift-concurrency/SKILL.md), and the repository development rule.

## Build Settings Fixes

### Debug Information Format (Debug)

Before (`project.pbxproj`):
```
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
```

After:
```
DEBUG_INFORMATION_FORMAT = dwarf;
```

### Compilation Mode (Debug)

Before:
```
SWIFT_COMPILATION_MODE = wholemodule;
```

After:
```
SWIFT_COMPILATION_MODE = singlefile;
```

### Enable Compilation Caching

Before (setting absent or):
```
COMPILATION_CACHE_ENABLE_CACHING = NO;
```

After:
```
COMPILATION_CACHE_ENABLE_CACHING = YES;
```

### Enable Eager Linking (Debug)

Before (setting absent):

After:
```
EAGER_LINKING = YES;
```

## Script Phase Fixes

### Add Configuration Guard

Before:
```bash
# Upload dSYMs to crash reporter
./scripts/upload-dsyms.sh
```

After:
```bash
# Upload dSYMs to crash reporter
[[ "$CONFIGURATION" != "Release" ]] && exit 0
./scripts/upload-dsyms.sh
```

### Add Input/Output Declarations

When a script has no declared inputs or outputs, Xcode runs it on every build. Declare them in the build phase or use `.xcfilelist` files for long lists.

Before (in Xcode build phase):
```
Input Files: (none)
Output Files: (none)
```

After:
```
Input Files:
  $(SRCROOT)/scripts/generate-constants.sh
  $(SRCROOT)/Config/constants.json

Output Files:
  $(DERIVED_FILE_DIR)/GeneratedConstants.swift
```

## Source-Level Fixes

### Add Explicit Type Annotations

Before:
```swift
let result = items.map { $0.value }.filter { $0 > threshold }.reduce(0, +)
```

After:
```swift
let mapped: [Double] = items.map { $0.value }
let filtered: [Double] = mapped.filter { $0 > threshold }
let result: Double = filtered.reduce(0, +)
```

### Break Complex Expressions

Before:
```swift
let config = try JSONDecoder().decode(
    AppConfig.self,
    from: Data(contentsOf: Bundle.main.url(forResource: "config", withExtension: "json")!)
)
```

After:
```swift
let configURL: URL = Bundle.main.url(forResource: "config", withExtension: "json")!
let configData: Data = try Data(contentsOf: configURL)
let config: AppConfig = try JSONDecoder().decode(AppConfig.self, from: configData)
```

### Mark Classes Final

Before:
```swift
class NetworkService {
    func fetchData() async throws -> Data { ... }
}
```

After:
```swift
final class NetworkService {
    func fetchData() async throws -> Data { ... }
}

```

Only apply when the class is not subclassed anywhere in the project. Search for `: NetworkService` and `class ... : NetworkService` before marking `final`.

### Tighten Access Control

Before:
```swift
class ViewModel {
    var internalState: State = .idle
    func processQueue() { ... }
}
```

After:
```swift
class ViewModel {
    private var internalState: State = .idle
    private func processQueue() { ... }
}
```

Apply `private` when the symbol is only used within the same declaration. Apply `fileprivate` when used within the same file but outside the declaration.

### Extract SwiftUI Subviews

Before:
```swift
struct ContentView: View {
    var body: some View {
        VStack {
            HStack {
                Text(user.name)
                Spacer()
                Button("Edit") { showEdit = true }
            }
            List(items) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Text(item.subtitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

After:
```swift
struct ContentView: View {
    var body: some View {
        VStack {
            UserHeaderView(user: user, showEdit: $showEdit)
            ItemListView(items: items)
        }
    }
}

struct UserHeaderView: View {
    let user: User
    @Binding var showEdit: Bool

    var body: some View {
        HStack {
            Text(user.name)
            Spacer()
            Button("Edit") { showEdit = true }
        }
    }
}

struct ItemListView: View {
    let items: [Item]

    var body: some View {
        List(items) { item in
            ItemRowView(item: item)
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack {
            Text(item.title)
            Spacer()
            Text(item.subtitle)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Add Explicit Closure Return Types

Before:
```swift
let handler = { value in
    guard let result = try? process(value) else { return nil }
    return result.transformed()
}
```

After:
```swift
let handler: (InputType) -> OutputType? = { (value: InputType) -> OutputType? in
    guard let result = try? process(value) else { return nil }
    return result.transformed()
}
```

## Module restructuring guard

Do not apply a generic module-splitting recipe to Koda. The single multiplatform `Koda` app target owns the product code, resources, and remote package dependencies. A new target or local package boundary requires an approved design that specifies product dependencies, resource ownership, access control, and validation.
