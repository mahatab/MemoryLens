import Foundation

struct MemoryConceptInfo {
    let title: String
    let macDescription: String
    let windowsEquivalent: String
    let windowsDescription: String
    let learnMore: String
}

enum MemoryEducation {

    // MARK: - System Memory Categories

    static let wired = MemoryConceptInfo(
        title: "Wired Memory",
        macDescription: "Memory that cannot be paged out to disk or compressed. Used by the kernel, drivers, and critical system structures that must always remain in physical RAM.",
        windowsEquivalent: "Nonpaged Pool",
        windowsDescription: "Windows calls this the Nonpaged Pool — kernel objects, driver allocations, and I/O buffers that must stay in physical memory at all times. Visible in Task Manager under 'Non-paged pool'.",
        learnMore: "Wired memory grows with connected devices, open network connections, and kernel extensions. High wired memory with nothing running may indicate a kext leak."
    )

    static let active = MemoryConceptInfo(
        title: "Active Memory",
        macDescription: "Memory currently in use and recently accessed. These pages are mapped to a process's virtual address space and have been read or written recently.",
        windowsEquivalent: "Working Set",
        windowsDescription: "In Windows, each process has a 'Working Set' — the set of pages currently resident in RAM. The total of all working sets roughly corresponds to macOS Active memory. RAMMap shows this per-process.",
        learnMore: "Active pages are the most 'alive' — the VM system will try to keep them in RAM. When memory pressure increases, less-recently-used active pages transition to inactive."
    )

    static let inactive = MemoryConceptInfo(
        title: "Inactive Memory",
        macDescription: "Pages that were recently active but haven't been accessed lately. Still in RAM as a cache — if the app needs them again, they can be reactivated instantly without disk I/O.",
        windowsEquivalent: "Standby List",
        windowsDescription: "Windows maintains a 'Standby List' of pages removed from working sets but still cached in RAM. RAMMap shows these as 'Standby' priority pages (0-7). Like macOS inactive memory, they're free-able but useful if re-accessed.",
        learnMore: "Inactive memory is NOT wasted — it's a smart cache. macOS keeps it around in case an app needs it again. Under memory pressure, inactive pages are the first to be reclaimed."
    )

    static let compressed = MemoryConceptInfo(
        title: "Compressed Memory",
        macDescription: "Pages that macOS has compressed in-memory instead of writing to disk. The compressor squeezes pages to roughly half size, keeping data accessible faster than swap.",
        windowsEquivalent: "Memory Compression (Win10+)",
        windowsDescription: "Windows 10+ added a similar 'Memory Compression' feature. The System process contains a 'Compression Store' that holds compressed pages. Visible in Task Manager as 'Memory compression' in the Memory tab.",
        learnMore: "macOS introduced memory compression in OS X Mavericks (10.9). It's often faster to decompress a page from RAM than to read it from an SSD. The compressor runs at near-memcpy speeds on Apple Silicon."
    )

    static let purgeable = MemoryConceptInfo(
        title: "Purgeable Memory",
        macDescription: "Memory that apps have marked as 're-creatable'. The system can reclaim it without saving to disk because the app can regenerate the data (caches, decoded images, etc.).",
        windowsEquivalent: "Standby List (low priority) / Offer API",
        windowsDescription: "Windows has 'MemoryPurge' and the 'Offer/Reclaim' API (OfferVirtualMemory) that serves a similar purpose. Low-priority standby pages can be discarded first. RAMMap shows standby priorities 0 (lowest) through 7.",
        learnMore: "Apps use NSPurgeableData or vm_purgable_control() to mark memory as purgeable. This is why closing browser tabs doesn't always free memory immediately — the cached data stays as purgeable until needed."
    )

    static let free = MemoryConceptInfo(
        title: "Free Memory",
        macDescription: "Pages not currently used by anything. On a well-functioning system, free memory is often low — macOS prefers to use available RAM for caches (inactive/purgeable) rather than leave it empty.",
        windowsEquivalent: "Free & Zeroed Lists",
        windowsDescription: "Windows splits free memory into 'Free' (contains stale data, needs zeroing) and 'Zeroed' (clean, ready for allocation). RAMMap shows both. The zero-page thread converts Free pages to Zeroed pages in the background.",
        learnMore: "Low free memory is normal and healthy. macOS (and Windows) both follow the principle: 'unused RAM is wasted RAM'. The OS fills free space with caches that speed up future operations."
    )

    // MARK: - VM Region Types

    static let textSegment = MemoryConceptInfo(
        title: "__TEXT Segment",
        macDescription: "Contains the executable machine code and read-only constants (string literals, etc.). Mapped as r-x (read + execute, no write) to prevent code modification.",
        windowsEquivalent: ".text Section (PE)",
        windowsDescription: "In Windows PE files, the .text section holds executable code. It's mapped as PAGE_EXECUTE_READ. ASLR randomizes the base address in both macOS and Windows.",
        learnMore: "Because __TEXT is read-only, the same physical pages can be shared between multiple processes running the same binary — this is called 'shared mapping' and saves significant RAM."
    )

    static let dataSegment = MemoryConceptInfo(
        title: "__DATA Segment",
        macDescription: "Contains mutable global and static variables. Mapped as rw- (read + write). Each process gets its own copy via copy-on-write semantics.",
        windowsEquivalent: ".data / .bss Sections (PE)",
        windowsDescription: "Windows PE files split this into .data (initialized globals) and .bss (uninitialized globals). Both are mapped as PAGE_READWRITE with copy-on-write for shared libraries.",
        learnMore: "__DATA uses copy-on-write: initially shared between processes, but when a process writes to a page, the kernel creates a private copy. This is why fork() is efficient — the child shares pages until it modifies them."
    )

    static let heap = MemoryConceptInfo(
        title: "Heap",
        macDescription: "Dynamically allocated memory (malloc, calloc, Swift/ObjC objects). Grows as the app allocates objects. Managed by libmalloc with multiple size-class 'zones'.",
        windowsEquivalent: "Heap (NT Heap / Segment Heap)",
        windowsDescription: "Windows uses the NT Heap (or Segment Heap on Win10+) for dynamic allocation. Each process has a default heap plus any additional heaps created via HeapCreate. RAMMap shows these as 'Heap' in the Physical Pages tab.",
        learnMore: "macOS malloc uses 'nano zones' for tiny allocations (<256 bytes), 'tiny' and 'small' zones for moderate sizes, and 'large' for big allocations (mapped directly with vm_allocate). Use 'heap <pid>' in Terminal to inspect."
    )

    static let stack = MemoryConceptInfo(
        title: "Stack",
        macDescription: "Thread stacks — each thread gets its own stack (default 512KB for secondary threads, 8MB for main thread). Grows downward in virtual address space with a guard page to catch overflows.",
        windowsEquivalent: "Thread Stack",
        windowsDescription: "Windows also allocates per-thread stacks (default 1MB committed, up to the reserved size). Stack overflows trigger a STATUS_STACK_OVERFLOW exception. Guard pages work similarly to macOS.",
        learnMore: "The guard page at the bottom of each stack is a non-accessible page. If a thread's stack grows into it, the kernel raises an exception (EXC_BAD_ACCESS on macOS, STATUS_STACK_OVERFLOW on Windows)."
    )

    static let dylib = MemoryConceptInfo(
        title: "Dynamic Library (dylib)",
        macDescription: "Shared libraries loaded by dyld. The __TEXT segments are shared across processes, while __DATA segments use copy-on-write.",
        windowsEquivalent: "DLL (Dynamic Link Library)",
        windowsDescription: "Windows DLLs serve the same purpose. Loaded by the PE loader, their code sections are shared. RAMMap shows DLL pages in the 'Shareable' category. Use 'listdlls' from Sysinternals to inspect loaded DLLs.",
        learnMore: "macOS caches shared library info in the dyld shared cache (/System/Library/dyld/dyld_shared_cache_*). On Apple Silicon, most system frameworks are pre-linked in this cache for fast loading."
    )

    static let anonymous = MemoryConceptInfo(
        title: "Anonymous Memory",
        macDescription: "Memory not backed by any file — typically heap allocations, stack pages, or mmap(MAP_ANON). If evicted from RAM, it goes to the swap file (compressed first).",
        windowsEquivalent: "Private Bytes / Page File-backed",
        windowsDescription: "In Windows, anonymous memory corresponds to 'Private Bytes' — committed virtual memory backed by the page file rather than a mapped file. RAMMap shows these as 'Process Private' in the Use Counts tab.",
        learnMore: "Anonymous memory is the main source of 'memory usage' for an app. Unlike file-backed pages (which can be re-read from disk), anonymous pages must be saved to swap if evicted."
    )

    // MARK: - Protection Flags

    static let protectionFlags = MemoryConceptInfo(
        title: "Protection Flags (rwx)",
        macDescription: "Each memory region has protection bits: Read (r), Write (w), Execute (x). The kernel enforces these — writing to r-x memory triggers EXC_BAD_ACCESS.",
        windowsEquivalent: "Page Protection (PAGE_*)",
        windowsDescription: "Windows uses PAGE_READONLY, PAGE_READWRITE, PAGE_EXECUTE_READ, PAGE_EXECUTE_READWRITE, etc. VirtualProtect() changes protection. DEP (Data Execution Prevention) = W^X enforcement.",
        learnMore: "Modern systems enforce W^X (write XOR execute): memory cannot be both writable and executable simultaneously. JIT compilers (like JavaScriptCore) must toggle protection: write code, then switch to r-x before executing."
    )

    // MARK: - General Concepts

    static let virtualVsPhysical = MemoryConceptInfo(
        title: "Virtual vs Physical Memory",
        macDescription: "Each process sees a flat 64-bit virtual address space. The kernel maps virtual pages to physical pages via page tables. Multiple virtual pages can map to the same physical page (sharing).",
        windowsEquivalent: "Same concept, same mechanism",
        windowsDescription: "Windows uses the same virtual memory model. The 'Virtual Size' column in Task Manager shows virtual, while 'Working Set' shows physical. RAMMap's unique value is showing the physical page breakdown.",
        learnMore: "Virtual memory enables: process isolation (each process has its own address space), memory overcommit (allocating more virtual than physical), and shared mappings (multiple processes sharing one physical copy)."
    )

    static let pageSize = MemoryConceptInfo(
        title: "Page Size",
        macDescription: "The smallest unit of memory the kernel manages. On Apple Silicon: 16KB pages. On Intel Macs: 4KB pages. All allocations are rounded up to page boundaries.",
        windowsEquivalent: "4KB pages (x86/x64), 64KB allocation granularity",
        windowsDescription: "Windows uses 4KB pages on x86/x64 and 16KB on ARM64. However, VirtualAlloc rounds up to 64KB 'allocation granularity'. Windows also supports 2MB 'large pages' for performance-critical allocations.",
        learnMore: "The page size affects memory efficiency. A 1-byte allocation still uses an entire page. This is why macOS's malloc uses 'nano zones' for tiny objects — packing many small allocations into shared pages."
    )

    static let memoryPressure = MemoryConceptInfo(
        title: "Memory Pressure",
        macDescription: "macOS uses a pressure-based model: Normal → Warn → Critical. As pressure increases, the VM compresses inactive pages, purges purgeable memory, then swaps to disk.",
        windowsEquivalent: "Low Memory Notification / Resource Manager",
        windowsDescription: "Windows uses CreateMemoryResourceNotification() to signal low memory. The Memory Manager trims working sets, writes modified pages to disk, and may terminate processes via the OOM killer (similar to macOS's Jetsam on iOS).",
        learnMore: "You can observe memory pressure with 'memory_pressure' command in Terminal. The kernel sends notifications to apps that have registered for them — well-behaved apps respond by freeing caches."
    )

    // MARK: - Lookup by category name

    static func info(for category: String) -> MemoryConceptInfo? {
        switch category.lowercased() {
        case "wired": return wired
        case "active": return active
        case "inactive": return inactive
        case "compressed": return compressed
        case "purgeable": return purgeable
        case "free": return free
        case "__text": return textSegment
        case "__data": return dataSegment
        case "heap": return heap
        case "stack": return stack
        case "dylib": return dylib
        case "anonymous", "mapped file": return anonymous
        default: return nil
        }
    }

    static let glossary: [(String, MemoryConceptInfo)] = [
        ("Virtual vs Physical Memory", virtualVsPhysical),
        ("Page Size", pageSize),
        ("Memory Pressure", memoryPressure),
        ("Wired Memory", wired),
        ("Active Memory", active),
        ("Inactive Memory", inactive),
        ("Compressed Memory", compressed),
        ("Purgeable Memory", purgeable),
        ("Free Memory", free),
        ("__TEXT Segment", textSegment),
        ("__DATA Segment", dataSegment),
        ("Heap", heap),
        ("Stack", stack),
        ("Dynamic Libraries", dylib),
        ("Anonymous Memory", anonymous),
        ("Protection Flags (rwx)", protectionFlags),
    ]
}
