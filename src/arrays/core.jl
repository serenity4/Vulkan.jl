
# we allow types as buffers, so eltype is a bit weird
eltype(v::Buffer{T}) where T = T
eltype(v::Buffer{T}) where T <: Array = eltype(T)

length(v::Buffer{T}) where T = div(v.size, sizeof(eltype(v)))
eltype_length(x) = 1
eltype_length(x::Type{F}) where F <: FixedArray = length(F)
flattened_length(v::Buffer{T}) where T = length(v) * eltype_length(eltype(v))


function get_descriptor(v::Buffer, offset = 0, range = v.size)
    descriptor = create(Vector{api.VkDescriptorBufferInfo}, (:buffer, v.buffer,
        :offset, offset,
        :range, range))
end


function map_buffer(device, buffer::Buffer)
    data_ref = Ref{Ptr{Cvoid}}(C_NULL)
    alloc_size = buffer.allocation_info.allocationSize
	err = api.vkMapMemory(device, buffer.mem, 0, alloc_size, 0, data_ref)
    check(err)
    data_ref[]
end

function unmap_buffer(device, buffer::Buffer)
    api.vkUnmapMemory(device, buffer.mem)
end
