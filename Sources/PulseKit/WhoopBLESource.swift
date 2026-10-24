#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth
import PulseCore

/// Live heart-rate source backed by a real WHOOP band (or any standard BLE HR strap)
/// over CoreBluetooth. It is a drop-in `HeartRateSource`: the CorrelationEngine neither
/// knows nor cares whether samples come from this or from `MockHeartRateSource`.
///
/// It subscribes to the Bluetooth SIG standard **Heart Rate Service** (`0x180D`) and its
/// **Heart Rate Measurement** characteristic (`0x2A37`), decoding each notification into
/// a `HRSample`. Using the standard profile also means any off-the-shelf BLE chest strap
/// works for testing when no WHOOP band is on hand.
///
/// ──────────────────────────────────────────────────────────────────────────────────────
/// IMPORTANT — what "pairing a WHOOP" actually is, and the one required step:
///
/// WHOOP's user-facing docs talk about "pairing" the band to devices like Peloton/Zwift.
/// Under the hood that is exactly this: WHOOP implements the *standard BLE Heart Rate
/// Profile*, so "pairing" means a BLE central (us) subscribing to service 0x180D. There is
/// no separate proprietary pairing transport to implement — standard CoreBluetooth is correct.
///
/// BUT: the WHOOP band does NOT advertise heart rate by default. The user must first turn on
/// **HR Broadcast** in the WHOOP app:
///     WHOOP app → Device Settings → Heart Rate Broadcast → Start Broadcast
/// Until that toggle is ON, the band emits nothing on 0x180D and `scanForPeripherals` will
/// silently find nothing. Surface this in onboarding so a forgotten toggle isn't mistaken
/// for a bug. (Ref: WHOOP support "How do I connect using Heart Rate Broadcast".)
/// ──────────────────────────────────────────────────────────────────────────────────────
///
/// Background note: to keep receiving samples with the app backgrounded, the host app must
/// enable the `bluetooth-central` background mode and (ideally) CoreBluetooth State
/// Preservation & Restoration. This class is written to cooperate with that.
public final class WhoopBLESource: NSObject, HeartRateSource {

    // Standard Bluetooth SIG assigned numbers.
    private static let heartRateServiceUUID = CBUUID(string: "180D")
    private static let heartRateMeasurementUUID = CBUUID(string: "2A37")

    public let samples: AsyncStream<HRSample>
    private let continuation: AsyncStream<HRSample>.Continuation

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    /// Optional: restrict to a peripheral whose advertised name contains this (e.g. "WHOOP").
    /// When nil, connects to the first device advertising the Heart Rate Service.
    private let nameFilter: String?

    /// Emitted connection-state changes, so UI can show "searching / connected / disconnected".
    public enum State: Equatable, Sendable {
        case poweredOff
        case unauthorized
        case scanning
        case connecting
        case connected
        case disconnected
        /// Scanned for `scanTimeout` seconds without finding a broadcasting band.
        /// Most likely cause: HR Broadcast is not turned on in the WHOOP app.
        case noDeviceFound
    }
    public var onStateChange: ((State) -> Void)?

    /// How long to scan before reporting `.noDeviceFound` (so the UI can prompt the user
    /// to enable HR Broadcast). Set to 0 to scan indefinitely.
    public var scanTimeout: TimeInterval = 15
    private var scanTimeoutWork: DispatchWorkItem?

    public init(nameFilter: String? = "WHOOP") {
        self.nameFilter = nameFilter
        var cont: AsyncStream<HRSample>.Continuation!
        self.samples = AsyncStream { cont = $0 }
        self.continuation = cont
        super.init()
    }

    public func start() {
        // Restoration identifier lets iOS relaunch us to redeliver BLE events after termination.
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "pulse.whoop.central"]
        )
    }

    public func stop() {
        if let p = peripheral {
            central?.cancelPeripheralConnection(p)
        }
        central?.stopScan()
        continuation.finish()
    }

    private func beginScan() {
        onStateChange?(.scanning)
        central.scanForPeripherals(withServices: [Self.heartRateServiceUUID], options: nil)

        // If nothing is found in time, the band most likely isn't broadcasting yet.
        scanTimeoutWork?.cancel()
        guard scanTimeout > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.peripheral == nil else { return }
            self.central.stopScan()
            self.onStateChange?(.noDeviceFound)
        }
        scanTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scanTimeout, execute: work)
    }

    /// Decode a Heart Rate Measurement characteristic value per the BLE spec.
    /// Byte 0 is a flags field; bit 0 indicates whether BPM is uint8 (0) or uint16 (1).
    private func decodeHeartRate(_ data: Data) -> Double? {
        guard let flags = data.first else { return nil }
        let is16Bit = (flags & 0x01) != 0
        if is16Bit {
            guard data.count >= 3 else { return nil }
            let bpm = UInt16(data[1]) | (UInt16(data[2]) << 8)
            return Double(bpm)
        } else {
            guard data.count >= 2 else { return nil }
            return Double(data[1])
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension WhoopBLESource: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            beginScan()
        case .poweredOff:
            onStateChange?(.poweredOff)
        case .unauthorized:
            onStateChange?(.unauthorized)
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        // Optionally match by advertised name (e.g. only WHOOP bands).
        if let filter = nameFilter {
            let advName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? peripheral.name ?? ""
            guard advName.localizedCaseInsensitiveContains(filter) else { return }
        }
        self.peripheral = peripheral
        peripheral.delegate = self
        scanTimeoutWork?.cancel()
        central.stopScan()
        onStateChange?(.connecting)
        central.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onStateChange?(.connected)
        peripheral.discoverServices([Self.heartRateServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral,
                               error: Error?) {
        onStateChange?(.disconnected)
        // Attempt to reconnect to the same band automatically.
        central.connect(peripheral, options: nil)
    }

    /// Called when iOS relaunches the app to restore BLE state after termination.
    public func centralManager(_ central: CBCentralManager,
                               willRestoreState dict: [String: Any]) {
        if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let p = restored.first {
            self.peripheral = p
            p.delegate = self
        }
    }
}

// MARK: - CBPeripheralDelegate
extension WhoopBLESource: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?
            .first(where: { $0.uuid == Self.heartRateServiceUUID }) else { return }
        peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService,
                           error: Error?) {
        guard let ch = service.characteristics?
            .first(where: { $0.uuid == Self.heartRateMeasurementUUID }) else { return }
        // Subscribe so the band pushes a notification on every measurement.
        peripheral.setNotifyValue(true, for: ch)
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic,
                           error: Error?) {
        guard characteristic.uuid == Self.heartRateMeasurementUUID,
              let data = characteristic.value,
              let bpm = decodeHeartRate(data) else { return }
        continuation.yield(HRSample(bpm: bpm, timestamp: Date()))
    }
}
#endif
