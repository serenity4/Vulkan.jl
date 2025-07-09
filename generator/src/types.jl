const ExprLike = Union{Symbol,Expr}
const Optional{T} = Union{Nothing,T}

is_tuple(ex) = isexpr(ex, :curly, 3) && ex.args[1] === :NTuple

is_ptr_to_ptr(ex) = !isnothing(ptrtype(ptrtype(ex)))
is_ptr(ex) = !isnothing(ptr_type(ex))

function ptr_type(ex)
    @trymatch ex begin
        :(Ptr{$T}) => T
        :(NTuple{$_, $T}) => T
    end
end
ntuple_type(ex) = @when :(NTuple{$N,$T}) = ex T

is_ntuple(ex) = !isnothing(ntuple_type(ex))

is_vulkan_type(name) = name ∈ [api.handles.name; api.structs.name; api.unions.name]

inner_type(ex) = @when :($T{$(args...)}) = ex map(args) do arg
    @match arg begin
        :(<:$t) => t
        _ => arg
    end
end

function innermost_type(ex::Expr)
    if is_ntuple(ex)
        innermost_type(ntuple_type(ex))
    else
        t = inner_type(ex)
        if !isnothing(t)
            if length(t) > 1
                error("Expected 1 inner type for $ex, found $(length(t)) ($t)")
            else
                innermost_type(first(t))
            end
        else
            ex
        end
    end
end

innermost_type(sym::Symbol) = sym
