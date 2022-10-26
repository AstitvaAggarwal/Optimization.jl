using SparseDiffTools, Symbolics
"""
AutoForwardDiff{chunksize} <: AbstractADType

An AbstractADType choice for use in OptimizationFunction for automatically
generating the unspecified derivative functions. Usage:

```julia
OptimizationFunction(f,AutoForwardDiff();kwargs...)
```

This uses the [ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl)
package. It is the fastest choice for small systems, especially with
heavy scalar interactions. It is easy to use and compatible with most
pure is Julia functions which have loose type restrictions. However,
because it's forward-mode, it scales poorly in comparison to other AD
choices. Hessian construction is suboptimal as it uses the forward-over-forward
approach.

- Compatible with GPUs
- Compatible with Hessian-based optimization
- Compatible with Hv-based optimization
- Compatible with constraints

Note that only the unspecified derivative functions are defined. For example,
if a `hess` function is supplied to the `OptimizationFunction`, then the
Hessian is not defined via ForwardDiff.
"""
struct AutoForwardDiff{chunksize} <: AbstractADType end
struct OptimizationTag end

function AutoForwardDiff(chunksize = nothing)
    AutoForwardDiff{chunksize}()
end

function default_chunk_size(len)
    if len < ForwardDiff.DEFAULT_CHUNK_THRESHOLD
        len
    else
        ForwardDiff.DEFAULT_CHUNK_THRESHOLD
    end
end

function instantiate_function(f::OptimizationFunction{true}, x,
                              adtype::AutoForwardDiff{_chunksize}, p,
                              num_cons = 0) where {_chunksize}
    chunksize = _chunksize === nothing ? default_chunk_size(length(x)) : _chunksize

    _f = (θ, args...) -> first(f.f(θ, p, args...))

    if f.grad === nothing
        gradcfg = ForwardDiff.GradientConfig(_f, x, ForwardDiff.Chunk{chunksize}(),
                                             ForwardDiff.Tag(OptimizationTag(), eltype(x)))
        grad = (res, θ, args...) -> ForwardDiff.gradient!(res, _f, θ,
                                                          gradcfg, Val{false}())
    else
        grad = (G, θ, args...) -> f.grad(G, θ, p, args...)
    end

    if f.hess === nothing
        sparsity = f.hess_prototype === nothing ? Symbolics.hessian_sparsity(_f, x) : f.hess_prototype
        colors = matrix_colors(sparsity)
        hescache = ForwardAutoColorHesCache(_f,
                              x,
                              colors,
                              sparsity, ForwardDiff.Tag(OptimizationTag(), eltype(x)))

        hess = (res, θ, args...) -> SparseDiffTools.autoauto_color_hessian!(res, _f, θ, hescache)
    else
        hess = (H, θ, args...) -> f.hess(H, θ, p, args...)
    end

    if f.hv === nothing
        hessvec = HesVec(_f, x)
        hv = function (H, θ, v, args...)
            res = ArrayInterfaceCore.zeromatrix(θ)
            hess(res, θ, args...)
            H .= res * v
        end
    else
        hv = f.hv
    end

    if f.cons === nothing
        cons = nothing
    else
        cons = (res, θ) -> f.cons(res, θ, p)
        cons_oop = (x) -> (_res = zeros(eltype(x), num_cons); cons(_res, x); _res)
    end

    cons_jac_colorvec = f.cons_jac_colorvec === nothing ? (1:length(x)) :
                        f.cons_jac_colorvec

    if cons !== nothing && f.cons_j === nothing
        cjconfig = ForwardColorJacCache(cons, x, chunksize,
                                              tag = ForwardDiff.Tag(OptimizationTag(), eltype(x)),
                                              colorvec = cons_jac_colorvec, sparsity = f.cons_jac_prototype)
        cons_j = function (J, θ)
            forwarddiff_color_jacobian!(J, cons, θ, cjconfig)
        end
    else
        cons_j = (J, θ) -> f.cons_j(J, θ, p)
    end

    if cons !== nothing && f.cons_h === nothing
        fncs = [(x) -> cons_oop(x)[i] for i in 1:num_cons]
        sparsity = [Symbolics.hessian_sparsity(fncs[i], x) for i in 1:num_cons]
        colors = matrix_colors.(sparsity)
        hess_config_cache = [ForwardAutoColorHesCache(fncs[i],
                              x,
                              colors[i],
                              sparsity[i], ForwardDiff.Tag(OptimizationTag(), eltype(x)))
                             for i in 1:num_cons]
        cons_h = function (res, θ)
            for i in 1:num_cons
                autoauto_color_hessian!(res[i], fncs[i], θ, hess_config_cache[i])
            end
        end
    else
        cons_h = (res, θ) -> f.cons_h(res, θ, p)
    end

    return OptimizationFunction{true}(f.f, adtype; grad = grad, hess = hess, hv = hv,
                                      cons = cons, cons_j = cons_j, cons_h = cons_h,
                                      hess_prototype = f.hess_prototype,
                                      cons_jac_prototype = f.cons_jac_prototype,
                                      cons_hess_prototype = f.cons_hess_prototype)
end
