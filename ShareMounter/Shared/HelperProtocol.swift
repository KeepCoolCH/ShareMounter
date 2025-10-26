import Foundation

@objc(ShareMounterHelperProtocol)
protocol ShareMounterHelperProtocol {
    func mountSMB(url: String, mountPoint: String, reply: @escaping (Bool, String) -> Void)
    func unmount(path: String, force: Bool, reply: @escaping (Bool, String) -> Void)
}
