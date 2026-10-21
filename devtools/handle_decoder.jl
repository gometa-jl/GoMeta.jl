# handle_decoder.jl — THE ONE decoder of an occurrence handle's bytes, shared by the development tools (devtools.jl) and the authored
# test runner (tests/authored/authored_tests.jl) — the creator's decision of 2026-10-03: one shared decoder,
# replacing the two private copies the two consumers held (the tools' `_dt_decode` family; the runner's `decode_handle` family).
# The Engine offers no reader of a handle's parts BY DESIGN: the answer function `evaluatedAltValue` spares consumers the handle
# this file is a development-tool and test-layer aid, never a consumer surface. Included by `devtools/devtools.jl` and by
# the runner, each guarded against a double include (`isdefined(@__MODULE__, :decode_handle)`).
#
# IS:   `decode_handle(b::Vector{UInt8}) -> NamedTuple | nothing` over the documented layout of src/occurrence.jl (schema 0x01): the schema
#       byte · the namespace (u16-BE length + UTF-8 bytes) · the grain byte · the path steps (u16-BE count; each a store byte + a u32-BE
#       ordinal = abs(idComponent)) · the origin steps (the same shape); the whole vector consumed.
# DOES: returns `(; namespace, grain, path, origin)` — `path` and `origin` as `Vector{Tuple{UInt8,UInt32}}` — or `nothing` when the bytes
#       do not decode CLEANLY: a schema byte ≠ 0x01, short or truncated bytes (BoundsError caught), trailing bytes, an invalid-UTF-8
#       namespace. It never half-decodes into a wrong anchor.
# REASONING: one layout, one reader. The two consumers' ARMS stay at their call sites: the tools render a handle that does not decode as
#       unanchored; the runner raises its own error on `nothing` (`decode_handle_strict`).
# PURPOSE: the handle's parts for a human's eye (the evals-rows-with-keys view — the tools' `trace` verb — and the FULL delivery view — `evals-tree`, `show_handles = true`) and for the runner's provenance assertion.

_hd_u16(b, i) = (UInt16(b[i]) << 8) | UInt16(b[i+1])
_hd_u32(b, i) = (UInt32(b[i]) << 24) | (UInt32(b[i+1]) << 16) | (UInt32(b[i+2]) << 8) | UInt32(b[i+3])
function _hd_steps(b, i)
    n = Int(_hd_u16(b, i)); i += 2
    v = Tuple{UInt8,UInt32}[]
    for _ in 1:n
        push!(v, (b[i], _hd_u32(b, i + 1))); i += 5
    end
    return v, i
end
function decode_handle(b::Vector{UInt8})
    (isempty(b) || b[1] != 0x01) && return nothing
    try
        i = 2
        nslen = Int(_hd_u16(b, i)); i += 2
        nsb = b[i:i+nslen-1]; i += nslen
        isvalid(String, nsb) || return nothing
        ns = String(nsb)
        grain = b[i]; i += 1
        path, i = _hd_steps(b, i)
        origin, i = _hd_steps(b, i)
        i == length(b) + 1 || return nothing
        return (; namespace = ns, grain, path, origin)
    catch e
        e isa BoundsError && return nothing
        rethrow()
    end
end
