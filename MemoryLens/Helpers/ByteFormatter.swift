import Foundation
import Darwin

enum ByteFormatter {
    static func format(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024

        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.1f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    static func format(_ bytes: Int64) -> String {
        if bytes < 0 {
            return "-" + format(UInt64(-bytes))
        }
        return format(UInt64(bytes))
    }

    static func formatPages(_ pageCount: UInt64) -> String {
        format(pageCount * UInt64(vm_page_size))
    }

    static func pagesToBytes(_ pageCount: UInt64) -> UInt64 {
        pageCount * UInt64(vm_page_size)
    }
}
