using FixedPointNumbers, Colors

type VulkanBuffer{T} <: VulkanArray{T, 1}
    mem::api.VkDeviceMemory
    buffer::api.VkBuffer
    allocation_info::api.VkMemoryAllocateInfo
    size::Int
end


# we allow types as buffers, so eltype is a bit weird
Base.eltype(v::VulkanBuffer{T}) where T = T
Base.eltype(v::VulkanBuffer{T}) where T<:Array = eltype(T)

Base.length(v::VulkanBuffer{T}) where T = div(v.size, sizeof(eltype(v)))
eltype_length(x) = 1
eltype_length(x::Type{F}) where F<:FixedArray = length(F)
flat_length(v::VulkanBuffer{T}) where T = length(v) * eltype_length(eltype(v))


function get_descriptor(v::VulkanBuffer, offset=0, range=v.size)
    descriptor = create(Vector{api.VkDescriptorBufferInfo}, (
        :buffer, v.buffer,
        :offset, offset,
        :range , range
    ))
end

"""
Find the memory type index, which selects the properties of the memory to be allocated,
as well as the heap the memory will come from.
"""
function get_memory_type(device, typebits, properties)
    memory_types = device.physical_device.memory_properties.memoryTypes
	for i_int=0:31
		i = UInt32(i_int)
		if ((typebits & 1) == 1)
			if ((memory_types[i+1].propertyFlags & UInt32(properties)) == UInt32(properties))
				return i
			end
		end
		typebits >>= 1
	end
	error("Can't get no memory type!")
end
function allocate_memory(device, allocation_info_ref)
    mem_ref = Ref{api.VkDeviceMemory}()
    err = api.vkAllocateMemory(device, allocation_info_ref, C_NULL, mem_ref)
    check(err)
    mem_ref[]
end

function CreateBuffer(device, container, usage, allocators=C_NULL)
    CreateBuffer(device, allocators, (
        :size, sizeof(container),
        :usage, usage
    ))

end
function get_memory_requirements(device, buffer)
    mem_requirements_ref = Ref{api.VkMemoryRequirements}()
	api.vkGetBufferMemoryRequirements(device, buffer, mem_requirements_ref)
    mem_requirements_ref[]
end
function map_buffer(device, buffer::VulkanBuffer)
    data_ref = Ref{Ptr{Cvoid}}(C_NULL)
    alloc_size =  buffer.allocation_info.allocationSize
	err = api.vkMapMemory(device, buffer.mem, 0, alloc_size, 0, data_ref)
    check(err)
    data_ref[]
end
function unmap_buffer(device, buffer::VulkanBuffer)
    api.vkUnmapMemory(device, buffer.mem)
end
function VulkanBuffer(container::T, device, usage) where T
    println(T)
    !is_referencable(T) && error(
        "A Vulkan buffer needs to be able to get a reference to $T, which it can't.
        Try using an array or a mutable composite Type
    ")
    buffer = CreateBuffer(device, container, usage)

    mem_requirements = get_memory_requirements(device, buffer)
    memtypeindex = get_memory_type(
        device,
        mem_requirements.memoryTypeBits,
        api.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
    )
    mem_alloc = create(Ref{api.VkMemoryAllocateInfo}, (
        :pNext, C_NULL,
        :memoryTypeIndex, memtypeindex,
        :allocationSize, mem_requirements.size
    ))
    mem = allocate_memory(device, mem_alloc)
    vkbuff = VulkanBuffer{T}(mem, buffer, mem_alloc[], sizeof(container))

    data_ptr = map_buffer(device, vkbuff)
    memcpy(data_ptr, container)
    unmap_buffer(device, vkbuff)

    err = api.vkBindBufferMemory(device, buffer, mem, 0)
    check(err)
    vkbuff
end

"""
Prefix for VkFormat
"""
type2prefix(::Type{T}) where T<:AbstractFloat = "SFLOAT"
type2prefix(::Type{T}) where T<:Integer = "SINT"
type2prefix(::Type{T}) where T<:Unsigned = "UINT"
type2prefix(::Type{T}) where T<:UFixed = "UNORM"
type2prefix(::Type{T}) where T<:Fixed = "SNORM"
type2prefix(::Type{T}) where T<:Union{Colorant, FixedArray} = type2prefix(eltype(T))

"""
For VkFormat, we need to specify the size of every component
"""
component_types(x::Type{T}) where T<:FixedArray = ntuple(i->eltype(T), length(T))
component_types(x::Type{T}) where T = ntuple(i->fieldtype(T, i), nfields(T))
component_types(x::Type{T}) where T<:Number = (T,)

"""
VkFormat looks like e.g RxGxBx, with x == size of the element type.
"""
component_string(x) = "RGBA" # RGBA is used for most types, even if they're Vecs or what not
# For color types we know better
function component_string(::Type{T}) where T<:Colorant
    if !(T <: AbstractRGB || (T<:TransparentColor && color_type(T) <: AbstractRGB))
        error("$T not supported. Try any AbstractRGB, or transparent AbstractRGB value")
    end
    string(T.name.name)
end

"""
Takes julia types, mostly immutables, Colorants or FixedSizeArrays and returns
the matching VkFormat symbol, which can be evaled to generate the matchin enum.
"""
function type2vkformatsymbol(T)
    type2vkformatsymbol(component_types(T), component_string(T), type2prefix(T))
end
function type2vkformatsymbol(types::Tuple, component_str, prefix)
    sym = "VK_FORMAT_"
    @assert length(types) <= length(component_str)
    for (c,t) in zip(component_str, types)
        sym *= string(c, sizeof(t)*8)
    end
    sym *= "_"*prefix
    symbol(sym)
end

"""
Takes julia types, mostly immutables, Colorants or FixedSizeArrays and returns
the matching VkFormat enum, needed for buffer/image layout specification.
We use a generated function for this, to avoid eval and inline the correct enum
for every type.
"""
@generated function type2vkformat{T}(x::Type{T})
    sym = type2vkformatsymbol(T)
    :(api.$sym)
end



type VertexArray

end

function setup_binding_description()
    VERTEX_BUFFER_BIND_ID = 0
    bindingDescriptions = create(Vector{api.VkVertexInputBindingDescription}, (
        :binding, VERTEX_BUFFER_BIND_ID,
        :stride, sizeof(Vertex{3, Float32}),
        :inputRate, api.VK_VERTEX_INPUT_RATE_VERTEX
    ))

    # Attribute descriptions
    # Describes memory layout and shader attribute locations
    # Location 0 : Position
    attributeDescriptions = create(Vector{api.VkVertexInputAttributeDescription}, (
            :binding, VERTEX_BUFFER_BIND_ID,
            :location, 0,
            :format, api.VK_FORMAT_R32G32B32_SFLOAT,
            :offset, 0,
        ),(
            :binding, VERTEX_BUFFER_BIND_ID,
            :location, 1,
            :format, api.VK_FORMAT_R32G32B32_SFLOAT,
            :offset, sizeof(Float32) * 3,
        ),(
            :binding, VERTEX_BUFFER_BIND_ID,
            :location, 2,
            :format, api.VK_FORMAT_R32G32B32_SFLOAT,
            :offset, sizeof(Float32) * 6,
        )
    )
    # Location 1 : Color
    # Assign to vertex buffer
    vi = create(Ref{api.VkPipelineVertexInputStateCreateInfo}, (
        :vertexBindingDescriptionCount, length(bindingDescriptions),
        :pVertexBindingDescriptions, bindingDescriptions,
        :vertexAttributeDescriptionCount, length(attributeDescriptions),
        :pVertexAttributeDescriptions, attributeDescriptions,
    ))
end



function Image{T,N}(device, array::Array{T,N}, usage,
        miplevels=1, arrayLayers=1,
        samples=VK_SAMPLE_COUNT_1_BIT,
        tiling=api.VK_IMAGE_TILING_OPTIMAL
    )
    dims = ntuple(3) do i
        i <= N ? size(array, i) : 1
    end
    image = CreateImage(device, C_NULL, (
        :imageType, VkImageType(N-1),
        :format, type2vkformat(T),
        :extent, api.VkExtent3D(dims...),
        :mipLevels, 1,
        :arrayLayers, 1,
        :samples, samples,
        :tiling, tiling,
        :usage, usage,
        :flags, 0
    ))
    Image{T, N}(ref, size(array))
end
