using VulkanGen

const destfile = joinpath(dirname(dirname(@__DIR__)), "generated", "vulkan_wrapper.jl")
const docfile = joinpath(dirname(dirname(@__DIR__)), "generated", "vulkan_docs.jl")

vw = VulkanWrapper()
@info "Vulkan successfully wrapped."
write(vw, destfile, docfile)
