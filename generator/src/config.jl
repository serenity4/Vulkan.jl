"""
Configuration structure which allow the selection of specific parts of the Vulkan API.
"""
Base.@kwdef struct WrapperConfig
    "Include core API (with core extensions)."
    wrap_core::Bool = true
    "Include beta (provisional) exensions. Provisional extensions may break between patch releases."
    include_provisional_exts::Bool = false
    "Platform-specific families of extensions to include."
    include_platforms::Vector{PlatformType} = []
    "Path the wrapper will be written to."
    destfile::String
end

include_provisional_exts(config::WrapperConfig) = config.include_provisional_exts || in(PLATFORM_PROVISIONAL, config.include_platforms)

function extensions(config::WrapperConfig)
    exts = filter(base_api.extensions) do extension
        !extension.is_provisional || include_provisional_exts(config) || return false
        in(extension.platform, config.include_platforms) || extension.platform == PLATFORM_NONE && config.wrap_core || return false
        in(VULKAN, extension.applicable) || return false
        return true
    end
end

function exclude_extensions(config::WrapperConfig)
    exts = extensions(config)
    return filter(!in(exts), base_api.extensions)
end

abstract type Platform end

struct Linux <: Platform end
struct MacOS <: Platform end
struct BSD <: Platform end
struct Windows <: Platform end

WrapperConfig(p::Platform, destfile; kwargs...) = WrapperConfig(; include_platforms = platform_extensions(p), destfile, kwargs...)

platform_extensions(::Linux) = [PLATFORM_WAYLAND, PLATFORM_XCB, PLATFORM_XLIB, PLATFORM_XLIB_XRANDR]
platform_extensions(::MacOS) = [PLATFORM_MACOS, PLATFORM_METAL]
platform_extensions(::BSD) = [PLATFORM_WAYLAND, PLATFORM_XCB, PLATFORM_XLIB, PLATFORM_XLIB_XRANDR]
platform_extensions(::Windows) = [PLATFORM_WIN32]
