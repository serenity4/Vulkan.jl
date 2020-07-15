#= 
Types for Vulkan =#

"""
there are lots of pointer types to wrap. We introduce an abstract type for this
to share some functionality
"""
abstract type VulkanPointerWrapper end

Base.cconvert(::Type{Ptr{Cvoid}}, x::VulkanPointerWrapper) = x
function Base.unsafe_convert(::Type{Ptr{Cvoid}}, x::VulkanPointerWrapper)
    if x.ref == C_NULL
        error("$x is NULL")
    end
    x.ref
end

# TODO finalize

struct PhysicalDevice <: VulkanPointerWrapper
    ref::api.VkPhysicalDevice
    memory_properties::api.VkPhysicalDeviceMemoryProperties
end

struct Device <: VulkanPointerWrapper
    ref::api.VkDevice
    physical_device::PhysicalDevice
end

struct Instance <: VulkanPointerWrapper
    ref::api.VkInstance
end

"""
A queue onto which you submit commands that the GPU reads and executes (asynchronously).
"""
struct Queue
    ref::VkQueue
end

@enum CommandBufferState RECORDING READY_FOR_SUBMIT RESETTED
struct CommandBuffer <: VulkanPointerWrapper
    ref::api.VkCommandBuffer
    state::CommandBufferState
    commandpool
end


# Array types

abstract type GPUArray{T,N} <: DenseArray{T,N} end

abstract type VulkanArray{T,N} <: GPUArray{T,N} end

struct DeviceMemory <: VulkanPointerWrapper
    ref::VkDeviceMemory
    device::Device
end
"""
Linear data for use on the device.
"""
struct Buffer{T} <: VulkanArray{T,1}
    ref::api.VkBuffer
    device::Device
    mem::DeviceMemory
    allocation_info::api.VkMemoryAllocateInfo
    dimension::Tuple{Int}
end

"""
Texture data (including dimensions & format) for use on the device.
"""
struct Image{T,N} <: VulkanArray{T,N}
    ref::VkImage
    device::Device
    mem::VkDeviceMemory
    dimension::NTuple{N,Int}
end

"""
 A collection of state required for a shader to sample textures (format, filtering etc).
"""
struct Sampler
    ref::VkSampler
end

struct VertexArray{T}
    id::Int
    parent::AbstractArray{T}
    pipeline_input_state
end


"""
A GPU-GPU synchronization object.
"""
struct Semaphore
    ref::VkSemaphore
end

"""
A GPU-CPU synchronization object.
"""
struct Fence
    ref::VkFence
end

"""
A compiled collection of GPU state setting commands, shaders and other such data. (Almost) everything the GPU needs to get ready for rendering/compute work.
"""
struct Pipeline
    ref::VkPipeline
end

"""
A cache used by the pipeline compilation process. It is used to avoid unnecessary recompilations and can be saved and restored to and from disk to speed up subsequent compilations (for instance, in subsequent runs of the application).
"""
struct PipelineCache
    ref::VkPipelineCache
end

"""
Swapchain : A "ring buffer" of images offered by the platform's presentation engine
(desktop compositors etc) on which the application can render and then submit for presentation.
"""
struct SwapChain <: VulkanPointerWrapper
    ref::Ref{api.VkSwapchainKHR}
    surface
    buffers
    images
    color_format
    color_space
    depth_format
    queue_node_index
    function SwapChain()
        new(Ref{api.VkSwapchainKHR}(api.VK_NULL_HANDLE))
    end
    function SwapChain(buffers, images, color_format, color_space, swapchain)
        new(buffers, images, color_format, color_space, swapchain)
    end
end

"""
Pool : A fast memory allocator specifically designed for objects of some specific type (descriptors, command buffers etc).
"""
abstract type Pool <: VulkanPointerWrapper end



struct DescriptorPool <: Pool
    ref::VkDescriptorPool
    device::Device
end
struct PipelineLayout <: VulkanPointerWrapper
    ref::VkPipelineLayout
    device::Device
end

struct DescriptorSetLayout <: VulkanPointerWrapper
    ref::VkDescriptorSetLayout
    device::Device
    pipeline_layout::PipelineLayout
end



struct GraphicsPipeline <: VulkanPointerWrapper
    ref::VkPipeline
    device::Device
end
