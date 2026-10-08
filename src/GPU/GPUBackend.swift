import Foundation

protocol GPUBackend: AnyObject {
    var name: String { get }
    var isHardwareAccelerated: Bool { get }
    var width: Int { get }
    var height: Int { get }
    func start()
    func stop()
    func submit(frame: Data, width: Int, height: Int)
}
