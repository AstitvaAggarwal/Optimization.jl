function convert_common_kwargs(opt::NonconvexIpopt.IpoptAlg, opt_kwargs;
    cb=nothing,
    maxiters=nothing,
    maxtime=nothing,
    abstol=nothing,
    reltol=nothing)

    conv_opt_kwargs = (; opt_kwargs...)

    if !isnothing(cb)
        @warn "common callback argument is currently not used by $(opt)"
    end
  
    if !isnothing(maxiters)
        conv_opt_kwargs = (; conv_opt_kwargs..., max_iter=maxiters)
    end

    if !isnothing(maxtime)
        conv_opt_kwargs = (; conv_opt_kwargs..., max_cpu_time = maxtime)
    end

    if !isnothing(abstol)
        @warn "common abstol argument is currently not used by $(opt)"
    end
    
    if !isnothing(reltol)
        conv_opt_kwargs = (; conv_opt_kwargs..., tol =reltol)
    end

    return conv_opt_kwargs
end

function _create_options(opt::NonconvexIpopt.IpoptAlg;
    opt_kwargs=nothing,
    sub_options=nothing,
    convergence_criteria=nothing)

    options = (; options = !isnothing(opt_kwargs) ? NonconvexIpopt.IpoptOptions(;opt_kwargs...) : NonconvexIpopt.IpoptOptions())
    
    return options
end

include("nonconvex.jl")