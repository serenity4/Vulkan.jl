module VulkanGen

using StructArrays: StructVector
using Accessors: @set
using Graphs
using MLStyle
using DocStringExtensions
using Reexport
using Dictionaries
using .Meta: isexpr
using Pkg: project
@reexport using VulkanSpec

@template (FUNCTIONS, METHODS, MACROS) = """
                                         $(DOCSTRING)
                                         $(TYPEDSIGNATURES)
                                         """

@template TYPES = """
                  $(DOCSTRING)
                  $(TYPEDEF)
                  $(TYPEDSIGNATURES)
                  $(TYPEDFIELDS)
                  $(SIGNATURES)
                  """

const VULKAN_API = Ref{VulkanAPI}()

__init__() = VULKAN_API[] = VulkanAPI(project().version)

include("types.jl")
include("exprs.jl")
include("type_conversions.jl")
include("naming_conventions.jl")
include("conventions.jl")
include("config.jl")
include("wrap.jl")
include("dependency_resolution.jl")
include("write.jl")

export
  # Naming Conventions
  ### Convention types
  CamelCaseLower,
  CamelCaseUpper,
  SnakeCaseLower,
  SnakeCaseUpper,

  ### Convention utilities
  detect_convention,
  nc_convert,
  remove_parts,
  remove_prefix,
  struct_name,

  # Expr
  name,
  category,
  deconstruct,
  reconstruct,
  rmlines,
  striplines,
  unblock,
  prettify,
  concat_exs,
  broadcast_ex,
  is_broadcast,
  to_expr,

  # Wrapping
  WrapperConfig,
  Platform,
  Linux,
  Windows,
  MacOS,
  BSD,
  extensions,
  filter_specs,
  VulkanWrapper,
  wrap,
  resolve_types,
  resolve_dependencies,

  ### Utility
  is_flag,
  is_returnedonly,
  contains_api_structs,
  promote_hl,

  ### Wrapper types
  WrapperNode,
  Definition,
  ConstantDefinition,
  EnumDefinition,
  BitmaskDefinition,
  StructDefinition,
  HandleDefinition,
  Constructor,
  Documented,
  MethodDefinition,
  AliasDeclaration,
  FromVk,
  Convert,
  GetProperty,
  APIFunction,
  Parent,
  exports,

  VULKAN_API

end # module VulkanGen
