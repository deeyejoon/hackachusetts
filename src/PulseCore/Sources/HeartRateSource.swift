import Foundation

/// A source of heart-rate samples.
///
/// This is the key seam in the architecture: the rest of the app depends only on this
/// protocol, never on a concrete source. That lets us swap implementations freely:
///
///   • `MockHeartRateSource`  — synthetic stream with injectable spikes (dev / demo, no hardware)
///   • `WhoopBLESource`       — live CoreBluetooth stream from a real WHOOP band (added later)
///   • `WhoopAPISource`       — batch samples from WHOOP's official REST API (compliant path)
///
/// Uses an AsyncStream so consumers can simply `for await sample in source.samples`.
public protocol HeartRateSource: AnyObject {
    /// An async stream of heart-rate samples. Begins emitting after `start()`.
    var samples: AsyncStream<HRSample> { get }

    /// Begin producing samples.
    func start()

    /// Stop producing samples and finish the stream.
    func stop()
}
