# Utilities for comparing functions
# Define isapprox so that we can use ≈ in tests

import Base: ==
function (==)(f1::MOI.VectorVariablewiseFunction, f2::MOI.VectorVariablewiseFunction)
    function canonicalize(f)
        s = Set{MOI.VariableReference}()
        for v in f.variables
            if v in s
                error("Repeated variable references in variablewise function")
            end
            push!(s,v)
        end
        return s
    end
    return canonicalize(d1) == canonicalize(d2)
end

function Base.isapprox(f1::MOI.ScalarAffineFunction{T}, f2::MOI.ScalarAffineFunction{T}; rtol = sqrt(eps), atol = 0, nans = false) where {T}
    function canonicalize(f)
        d = Dict{MOI.VariableReference,T}()
        @assert length(f.variables) == length(f.coefficients)
        for k in 1:length(f.variables)
            d[f.variables[k]] = f.coefficients[k] + get(d, f.variables[k], zero(T))
        end
        return (d,f.constant)
    end
    d1, c1 = canonicalize(f1)
    d2, c2 = canonicalize(f2)
    for (var,coef) in d2
        d1[var] = get(d1,var,zero(T)) - coef
    end
    return isapprox([c2-c1;collect(values(d1))], zeros(T,length(d1)), rtol=rtol, atol=atol, nans=nans)
end
