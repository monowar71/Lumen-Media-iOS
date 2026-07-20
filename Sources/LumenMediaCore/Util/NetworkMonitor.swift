import Foundation
import Network

/// Observes network path and exposes LAN vs external (cellular / constrained).
public final class NetworkMonitor: @unchecked Sendable {
    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.lumenmedia.network")
    private let lock = NSLock()
    private var _kind: ConnectionKind = .lan

    public var kind: ConnectionKind {
        lock.lock()
        defer { lock.unlock() }
        return _kind
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let next: ConnectionKind
            if path.usesInterfaceType(.cellular) || path.isConstrained || path.isExpensive {
                next = .external
            } else {
                next = .lan
            }
            self.lock.lock()
            self._kind = next
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }
}
