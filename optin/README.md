# optin/ — modules you load on purpose

*Owner ruling 2026-08-28 (D-14): the readers and evaluators that GoMeta calls during its own evaluation, but that are deliberately kept OUTSIDE the package, live here — one module per opt-in. None of them is loaded by `using GoMeta`; none can be reached from a processed document.*

## What is here

| module | what it adds | risk |
|---|---|---|
| `condition_modes_opt_in.jl` | two more ways of reading a `#~` condition: `:full_julia_parse_v1` (full Julia grammar accepted, nothing executed) and `:full_eval_v1` (the executing mode — the condition is evaluated by Julia, as the original GoMeta did) | the executing mode runs code found in the document; use it only on files whose every byte you wrote |

## How to use it (the two acts, both yours — never a document's)

```julia
using GoMeta
include(joinpath(pkgdir(GoMeta), "optin", "condition_modes_opt_in.jl"))   # act 1: load the module
result = goMeta(bytes; config = GoMetaConfig(profile = :jl_share_v1_full_parse))  # act 2: name the profile
# or, for the executing mode:
result = goMeta(bytes; config = GoMetaConfig(profile = :jl_share_v1_full_eval))
```

Without both acts every condition is read by the default `:closed_v1` reader (GoMeta's own small grammar; no Julia code is built or run). Naming an opt-in profile without having loaded the module is refused with a message that says so.

## The default, for comparison

`:closed_v1` (`src/condition.jl`) reads a condition with GoMeta's own scanner and parser — label and state names, `!`, `&`, `|`, `&&`, `||`, parentheses, the `,` that means "or" — into a small tree that GoMeta's own evaluator decides. Text outside that grammar is refused with a typed message, never executed.

## Adding another opt-in

One file per module; it registers itself through the versioned seam (`GoMeta.register_condition_mode!` today; the same shape for future kinds), documents its two acts at the top, and states its risk in the table above.
