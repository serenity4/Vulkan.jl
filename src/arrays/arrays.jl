function Buffer(container::T, device, usage, allocators = C_NULL) where T
    !is_referencable(T) && error(
        "A Vulkan buffer needs to be able to get a reference to $T, which it can't.
        Try using an array or a mutable composite Type
    ")
    buffer = CreateBuffer(device, allocators, (:size, sizeof(container),
        :usage, usage))

    mem_requirements = get_memory_requirements(device, buffer)
    memtypeindex = get_memory_type(
        device,
        mem_requirements.memoryTypeBits,
        api.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
    )
    mem_alloc = create(Ref{api.VkMemoryAllocateInfo}, (:pNext, C_NULL,
        :memoryTypeIndex, memtypeindex,
        :allocationSize, mem_requirements.size))
    mem = allocate_memory(device, mem_alloc)
    vkbuff = Buffer{T}(mem, device, buffer, mem_alloc[], sizeof(container))

    data_ptr = map_buffer(device, vkbuff)
    memcpy(data_ptr, container)
    unmap_buffer(device, vkbuff)

    err = api.vkBindBufferMemory(device, buffer, mem, 0)
    check(err)
    vkbuff
end

function DeviceMemory(device, allocation_info_ref)
    mem_ref = Ref{api.VkDeviceMemory}()
    err = api.vkAllocateMemory(device, allocation_info_ref, C_NULL, mem_ref)
    check(err)
    DeviceMemory(mem_ref[], device)
end




"""
Prefix for VkFormat
"""
type2prefix(::Type{T}) where T <: AbstractFloat = "SFLOAT"
type2prefix(::Type{T}) where T <: Integer = "SINT"
type2prefix(::Type{T}) where T <: Unsigned = "UINT"
type2prefix(::Type{T}) where T <: UFixed = "UNORM"
type2prefix(::Type{T}) where T <: Fixed = "SNORM"
type2prefix(::Type{T}) where T <: Union{Colorant,FixedArraytype} = type2prefix(eltype(T))

"""
For VkFormat, we need to specify the size of every component
"""
component_types(x::Type{T}) where T <: FixedArray = ntuple(i->eltype(T), length(T))
component_types(x::Type{T}) where T = ntuple(i->fieldtype(T, i), nfields(T))
component_types(x::Type{T}) where T <: Number = (T,)

"""
VkFormat looks like e.g RxGxBx, with x == size of the element type.
"""
component_string(x) = "RGBA" # RGBA is used for most types, even if they're Vecs or what not
# For color types we know better
function component_string(::Type{T}) where T <: Colorant
    if !(T <: AbstractRGB || (T <: TransparentColor && color_type(T) <: AbstractRGB))
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
    for (c, t) in zip(component_str, types)
        sym *= string(c, sizeof(t) * 8)
    end
    sym *= "_" * prefix
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
    if !isdefined(api, sym)
        error("Type $T doesn't have a matching vulkan type.")
    end
    :(api.$sym)
end




function next_vertex_binding_id end
let binding_counter = Ref(0)
    function next_vertex_binding_id()
        id = binding_counter[]
        binding_counter[] = id + 1
        id
    end
end

function input_attribute_description(::Type{T}, id) where T <: Number
    [api.VkVertexInputAttributeDescription(
        id, 0, type2vkformat(T), 0,
    )]
end
function input_attribute_description(::Type{T}, id) where T
    attribute_bindings = map(1:nfields(T)) do i
        t = fieldtype(T, i)
        api.VkVertexInputAttributeDescription(
            id, i - 1, type2vkformat(t), 0,
        )
    end
end

function vertex_input_binding_description(::Vector{T}, id, input_rate) where T
    [api.VkVertexInputBindingDescription(id, sizeof(T), input_rate)]
end

function VertexArray(A::AbstractArray{T}) where T
    id = next_vertex_binding_id()

    binding_descriptions = vertex_input_binding_description(b)
    attribute_description = input_attribute_description(T, id)

    vi = create(Ref{api.VkPipelineVertexInputStateCreateInfo}, (:vertexBindingDescriptionCount, length(binding_descriptions),
        :pVertexBindingDescriptions, binding_descriptions,
        :vertexAttributeDescriptionCount, length(attribute_description),
        :pVertexAttributeDescriptions, attribute_description,))
    VertexArray(id, A, vi)
end



function Image(device, array::Array{T,N}, usage,
        miplevels = 1, arrayLayers = 1,
        samples = VK_SAMPLE_COUNT_1_BIT,
        tiling = api.VK_IMAGE_TILING_OPTIMAL
    )
    dims = ntuple(3) do i
        i <= N ? size(array, i) : 1
    end
    image = CreateImage(device, C_NULL, (:imageType, VkImageType(N - 1),
        :format, type2vkformat(T),
        :extent, api.VkExtent3D(dims...),
        :mipLevels, 1,
        :arrayLayers, 1,
        :samples, samples,
        :tiling, tiling,
        :usage, usage,
        :flags, 0))
    Image{T,N}(ref, size(array))
end
