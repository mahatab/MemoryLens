import Foundation
import Darwin

struct ProcessInfo: Identifiable, Sendable {
    let id: pid_t
    let pid: pid_t
    let name: String
    let residentSize: UInt64
    let virtualSize: UInt64
}

@MainActor
final class ProcessListService: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var isRoot: Bool

    init() {
        isRoot = getuid() == 0
        refresh()
    }

    func refresh() {
        let result = Self.fetchProcesses()
        self.processes = result
    }

    private static func fetchProcesses() -> [ProcessInfo] {
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(pidCount))
        let bufferSize = Int32(pids.count * MemoryLayout<pid_t>.size)
        let bytesWritten = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, bufferSize)
        }

        guard bytesWritten > 0 else { return [] }
        let actualCount = Int(bytesWritten)

        var result: [ProcessInfo] = []
        result.reserveCapacity(actualCount)

        for i in 0..<actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            let name = getProcessName(pid: pid)
            let (rss, vsize) = getMemoryInfo(pid: pid)

            result.append(ProcessInfo(
                id: pid,
                pid: pid,
                name: name,
                residentSize: rss,
                virtualSize: vsize
            ))
        }

        result.sort { $0.residentSize > $1.residentSize }
        return result
    }

    private static func getProcessName(pid: pid_t) -> String {
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let len = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if len > 0 {
            return String(cString: nameBuffer)
        }
        return "(unknown)"
    }

    private static func getMemoryInfo(pid: pid_t) -> (rss: UInt64, vsize: UInt64) {
        var taskPort: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &taskPort)
        guard kr == KERN_SUCCESS else {
            return (0, 0)
        }
        defer {
            mach_port_deallocate(mach_task_self_, taskPort)
        }

        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(taskPort, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0)
        }

        return (UInt64(info.resident_size), UInt64(info.virtual_size))
    }
}
