import SwiftUI

/// Wraps `@StateObject` creation when dependencies come from `@EnvironmentObject`.
struct StatefulViewModel<VM: ObservableObject, Content: View>: View {
    @StateObject private var viewModel: VM
    private let content: (VM) -> Content

    init(
        _ make: @autoclosure @escaping () -> VM,
        @ViewBuilder content: @escaping (VM) -> Content
    ) {
        _viewModel = StateObject(wrappedValue: make())
        self.content = content
    }

    var body: some View {
        content(viewModel)
    }
}
