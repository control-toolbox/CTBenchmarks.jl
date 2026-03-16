# ═══════════════════════════════════════════════════════════════════════════════
# CTBenchmarks Documentation Utilities
# ═══════════════════════════════════════════════════════════════════════════════
#
# This file loads the CTBenchmarksDocUtils module and imports all exported functions
# into the Main namespace for use in documentation templates and make.jl.
#
# ═══════════════════════════════════════════════════════════════════════════════

# Load the main module
include(joinpath(@__DIR__, "CTBenchmarksDocUtils.jl"))

# Import all exported functions into Main namespace
using .CTBenchmarksDocUtils

# Re-export for convenience (makes functions available without prefix)
for name in names(CTBenchmarksDocUtils)
    if name != :CTBenchmarksDocUtils
        item = getfield(CTBenchmarksDocUtils, name)
        # For modules, make them available directly
        if item isa Module
            @eval const $name = $item
        else
            @eval const $name = CTBenchmarksDocUtils.$name
        end
    end
end
