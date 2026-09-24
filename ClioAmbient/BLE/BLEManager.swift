import Foundation
import CoreBluetooth
import Combine

/// Gestion Bluetooth native (CoreBluetooth) du contrôleur LEDCAR-01.
/// - scanne les appareils dont le nom commence par « LEDCAR »
/// - se reconnecte automatiquement au dernier contrôleur utilisé
/// - envoie les trames une par une, en ne gardant que la dernière valeur par type (glisser un slider ne sature pas la file)
final class BLEManager: NSObject, ObservableObject {
    enum Status: Equatable {
        case bluetoothOff, unauthorized, idle, scanning, connecting, connected
        var label: String {
            switch self {
            case .bluetoothOff: return "Bluetooth désactivé"
            case .unauthorized: return "Accès Bluetooth refusé"
            case .idle: return "Déconnecté"
            case .scanning: return "Recherche…"
            case .connecting: return "Connexion…"
            case .connected: return "Connecté"
            }
        }
    }

    struct Found: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var deviceName: String?
    @Published private(set) var found: [Found] = []
    /// Journal séparé : il change à chaque trame, on ne veut pas redessiner toute l'appli pour ça.
    let console = BLEConsole()

    /// Appelé à chaque (re)connexion réussie, pour renvoyer l'état courant.
    var onConnected: (() -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var discovered: [UUID: CBPeripheral] = [:]
    private var userDisconnected = false
    private var wantsScan = false

    private var pendingKeys: [String] = []
    private var pending: [String: Data] = [:]
    private var pumping = false

    private let lastDeviceKey = "ble.lastDevice"

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isConnected: Bool { status == .connected }

    // MARK: - Actions

    func startScan() {
        wantsScan = true
        guard central.state == .poweredOn else { return }
        userDisconnected = false
        found = []
        discovered = [:]
        status = .scanning
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        log("Recherche des contrôleurs LEDCAR…")
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.status == .scanning else { return }
            self.central.stopScan()
            self.status = .idle
            if self.found.isEmpty { self.log("Aucun contrôleur trouvé") }
        }
    }

    func connect(_ id: UUID) {
        guard let p = discovered[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        central.stopScan()
        connect(p)
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        status = .connecting
        deviceName = p.name
        central.connect(p, options: nil)
        log("Connexion à \(p.name ?? "contrôleur")…")
    }

    func disconnect() {
        userDisconnected = true
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    /// Tente de retrouver le dernier contrôleur connu, sinon lance un scan.
    private func autoConnect() {
        if let s = UserDefaults.standard.string(forKey: lastDeviceKey), let id = UUID(uuidString: s),
           let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(p)
        } else {
            startScan()
        }
    }

    // MARK: - Envoi

    /// Envoie une trame. Si une trame de même `key` attend encore, elle est remplacée (la dernière valeur gagne).
    func send(_ key: String, _ data: Data) {
        guard data.count == 9 else { log("✖ trame invalide \(key)"); return }
        if pending[key] == nil { pendingKeys.append(key) }
        pending[key] = data
        pump()
    }

    private func pump() {
        guard !pumping else { return }
        guard let p = peripheral, let c = writeChar, status == .connected else {
            pending.removeAll(); pendingKeys.removeAll(); return
        }
        guard !pendingKeys.isEmpty else { return }
        pumping = true
        let key = pendingKeys.removeFirst()
        if let data = pending.removeValue(forKey: key) {
            let type: CBCharacteristicWriteType = c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            p.writeValue(data, for: c, type: type)
            log("→ " + LED.hex(data))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) { [weak self] in
            self?.pumping = false
            self?.pump()
        }
    }

    func log(_ s: String) { console.append(s) }
}

/// Journal de la console développeur, observé uniquement par la vue qui l'affiche.
final class BLEConsole: ObservableObject {
    struct Line: Identifiable { let id: Int; let text: String }
    @Published private(set) var lines: [Line] = []
    private var next = 0
    private static let time: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f }()

    func append(_ s: String) {
        lines.append(Line(id: next, text: Self.time.string(from: Date()) + "  " + s))
        next += 1
        if lines.count > 250 { lines.removeFirst(lines.count - 250) }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = .idle
            autoConnect()
        case .unauthorized:
            status = .unauthorized
        default:
            status = .bluetoothOff
            writeChar = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        guard name.hasPrefix(LEDUUID.namePrefix) else { return }
        discovered[peripheral.identifier] = peripheral
        if !found.contains(where: { $0.id == peripheral.identifier }) {
            found.append(Found(id: peripheral.identifier, name: name, rssi: RSSI.intValue))
            log("Trouvé : \(name) (\(RSSI) dBm)")
        }
        // Un seul contrôleur trouvé → connexion directe
        if found.count == 1, status == .scanning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self, self.status == .scanning, self.found.count == 1 else { return }
                self.connect(peripheral.identifier)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: lastDeviceKey)
        peripheral.discoverServices([LEDUUID.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("✖ Échec connexion : \(error?.localizedDescription ?? "?")")
        status = .idle
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeChar = nil
        log("Déconnecté")
        if userDisconnected {
            status = .idle
        } else {
            // Reconnexion automatique : iOS attend que l'appareil soit de nouveau à portée
            status = .connecting
            central.connect(peripheral, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let svc = peripheral.services?.first(where: { $0.uuid == LEDUUID.service }) else {
            log("✖ Service FFE0 introuvable"); return
        }
        peripheral.discoverCharacteristics([LEDUUID.write, LEDUUID.notify], for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            if c.uuid == LEDUUID.write { writeChar = c }
            if c.uuid == LEDUUID.notify { peripheral.setNotifyValue(true, for: c) }
        }
        guard writeChar != nil else { log("✖ Caractéristique FFE1 introuvable"); return }
        status = .connected
        deviceName = peripheral.name
        log("Connecté à \(peripheral.name ?? "LEDCAR")")
        onConnected?()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let v = characteristic.value { log("← " + LED.hex(v)) }
    }
}
