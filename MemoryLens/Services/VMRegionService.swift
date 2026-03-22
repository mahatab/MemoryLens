import Foundation
import Darwin

struct VMRegionInfo: Identifiable {
    let id = UUID()
    let startAddress: UInt64
    let endAddress: UInt64
    let size: UInt64
    let protection: String
    let regionType: String
    let mappedFile: String
}

private let vmRegionBasicInfoCount64 = mach_msg_type_number_t(
    MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size
)

enum VMRegionService {
    static func fetchRegions(for pid: pid_t) -> [VMRegionInfo] {
        var taskPort: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &taskPort)
        guard kr == KERN_SUCCESS else { return [] }
        defer { mach_port_deallocate(mach_task_self_, taskPort) }

        var regions: [VMRegionInfo] = []
        var address: mach_vm_address_t = 0

        while true {
            var size: mach_vm_size_t = 0
            var info = vm_region_basic_info_data_64_t()
            var count = vmRegionBasicInfoCount64
            var objectName: mach_port_t = 0

            let result = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: Int32.self, capacity: Int(count)) { intPtr in
                    mach_vm_region(
                        taskPort,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPtr,
                        &count,
                        &objectName
                    )
                }
            }

            guard result == KERN_SUCCESS else { break }

            let prot = decodeProtection(info.protection)
            let filename = getRegionFilename(pid: pid, address: address)
            let type = deriveRegionType(filename: filename, address: address)

            regions.append(VMRegionInfo(
                startAddress: address,
                endAddress: address + size,
                size: size,
                protection: prot,
                regionType: type,
                mappedFile: filename.isEmpty ? "[anonymous]" : filename
            ))

            address += size
        }

        return regions
    }

    private static func decodeProtection(_ prot: vm_prot_t) -> String {
        var result = ""
        result += (prot & VM_PROT_READ) != 0 ? "r" : "-"
        result += (prot & VM_PROT_WRITE) != 0 ? "w" : "-"
        result += (prot & VM_PROT_EXECUTE) != 0 ? "x" : "-"
        return result
    }

    private static func getRegionFilename(pid: pid_t, address: UInt64) -> String {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let len = proc_regionfilename(pid, address, &pathBuffer, UInt32(pathBuffer.count))
        guard len > 0 else { return "" }
        return String(cString: pathBuffer)
    }

    private static func deriveRegionType(filename: String, address: UInt64) -> String {
        if filename.isEmpty {
            return "anonymous"
        }
        if filename.contains("__TEXT") {
            return "__TEXT"
        }
        if filename.contains("__DATA") {
            return "__DATA"
        }
        if filename.contains("__LINKEDIT") {
            return "__LINKEDIT"
        }
        if filename.hasSuffix(".dylib") {
            return "dylib"
        }
        if filename.contains("/dyld") {
            return "dyld"
        }
        return "mapped file"
    }
}
