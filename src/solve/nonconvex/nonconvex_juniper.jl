function convert_common_kwargs(opt::NonconvexJuniper.JuniperIpoptAlg, opt_kwargs;
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
        @warn "common maxiters argument is currently not used by $(opt)"
    end

    if !isnothing(maxtime)
        conv_opt_kwargs = (; conv_opt_kwargs..., time_limit = maxtime)
    end

    if !isnothing(abstol)
        conv_opt_kwargs = (; conv_opt_kwargs..., atol = abstol)
    end
    
    if !isnothing(reltol)
        @warn "common reltol argument is currently not used by $(opt)"
    end

    return conv_opt_kwargs
end

function _create_options(opt::NonconvexJuniper.JuniperIpoptAlg;
    opt_kwargs=nothing,
    sub_options=nothing,
    convergence_criteria=nothing)

    options = (; options = !isnothing(opt_kwargs) ? NonconvexJuniper.JuniperIpoptOptions(;opt_kwargs...) : NonconvexJuniper.JuniperIpoptOptions())
    
    return options
end

include("nonconvex.jl")