import Foundation
import Darwin

struct SystemMemoryStats {
    var totalRAM: UInt64 = 0
    var free: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var purgeable: UInt64 = 0

    // VM activity stats
    var pageFaults: UInt64 = 0
    var pageins: UInt64 = 0
    var pageouts: UInt64 = 0
    var swapins: UInt64 = 0
    var swapouts: UInt64 = 0
    var cowFaults: UInt64 = 0
    var reactivations: UInt64 = 0
    var purges: UInt64 = 0
    var decompressions: UInt64 = 0
    var compressions: UInt64 = 0
    var swapUsed: UInt64 = 0

    var used: UInt64 {
        active + inactive + wired + compressed
    }

    func percentage(of value: UInt64) -> Double {
        guard totalRAM > 0 else { return 0 }
        return Double(value) / Double(totalRAM) * 100
    }
}

@MainActor
final class MemoryStatsService: ObservableObject {
    @Published var stats = SystemMemoryStats()

    init() {
        refresh()
    }

    func refresh() {
        let totalRAM = Self.fetchTotalRAM()
        let swapUsed = Self.fetchSwapUsage()
        if let vmStats = Self.fetchVMStats() {
            let pageSize = UInt64(vm_page_size)
            stats = SystemMemoryStats(
                totalRAM: totalRAM,
                free: UInt64(vmStats.free_count) * pageSize,
                active: UInt64(vmStats.active_count) * pageSize,
                inactive: UInt64(vmStats.inactive_count) * pageSize,
                wired: UInt64(vmStats.wire_count) * pageSize,
                compressed: UInt64(vmStats.compressor_page_count) * pageSize,
                purgeable: UInt64(vmStats.purgeable_count) * pageSize,
                pageFaults: UInt64(vmStats.faults),
                pageins: UInt64(vmStats.pageins),
                pageouts: UInt64(vmStats.pageouts),
                swapins: UInt64(vmStats.swapins),
                swapouts: UInt64(vmStats.swapouts),
                cowFaults: UInt64(vmStats.cow_faults),
                reactivations: UInt64(vmStats.reactivations),
                purges: UInt64(vmStats.purges),
                decompressions: UInt64(vmStats.decompressions),
                compressions: UInt64(vmStats.compressions),
                swapUsed: swapUsed
            )
        }
    }

    private static func fetchTotalRAM() -> UInt64 {
        var hostInfo = host_basic_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &hostInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_info(mach_host_self(), HOST_BASIC_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return hostInfo.max_mem
    }

    private static func fetchVMStats() -> vm_statistics64_data_t? {
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return vmStats
    }

    private static func fetchSwapUsage() -> UInt64 {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        guard result == 0 else { return 0 }
        return UInt64(swapUsage.xsu_used)
    }
}
