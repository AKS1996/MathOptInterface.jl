function tofun(f::MOI.VectorOfVariables)
    nv = length(f.variables)
    MOI.VectorAffineFunction(collect(1:nv), f.variables, ones(nv), zeros(nv))
end

"""
    _SOCtoPSDCaff{T}(f::MOI.VectorAffineFunction{T}, g::MOI.ScalarAffineFunction{T})

Builds a VectorAffineFunction representing the upper (or lower) triangular part of the matrix
[ f[1]     f[2:end]' ]
[ f[2:end] g * I     ]
"""
function _SOCtoPSDCaff(f::MOI.VectorAffineFunction{T}, g::MOI.ScalarAffineFunction{T}) where T
    dim = length(f.constant)
    n = div(dim * (dim+1), 2)
    # Needs to add t*I
    N0 = length(f.variables)
    Ni = length(g.variables)
    N = N0 + (dim-1) * Ni
    outputindex  = Vector{Int}(N); outputindex[1:N0]  = trimap.(f.outputindex, 1)
    variables    = Vector{VI}(N);  variables[1:N0]    = f.variables
    coefficients = Vector{T}(N);   coefficients[1:N0] = f.coefficients
    constant = [f.constant; zeros(T, n - length(f.constant))]
    cur = N0
    for i in 2:dim
        k = trimap(i, i)
        outputindex[cur+(1:Ni)]  = k
        variables[cur+(1:Ni)]    = g.variables
        coefficients[cur+(1:Ni)] = g.coefficients
        constant[k] = g.constant
        cur += Ni
    end
    MOI.VectorAffineFunction(outputindex, variables, coefficients, constant)
end

"""
The `SOCtoPSDCBridge` transforms the second order cone constraint ``\\lVert x \\rVert \\le t`` into the semidefinite cone constraints
```math
\\begin{pmatrix}
  t & x^\\top\\\\
  x & tI
\\end{pmatrix} \\succeq 0
```
Indeed by the Schur Complement, it is positive definite iff
```math
\\begin{align*}
  tI & \\succ 0\\\\
  t - x^\\top (tI)^{-1} x & \\succ 0
\\end{align*}
```
which is equivalent to
```math
\\begin{align*}
  t & > 0\\\\
  t^2 & > x^\\top x
\\end{align*}
```
"""
struct SOCtoPSDCBridge{T} <: AbstractBridge
    dim::Int
    cr::CI{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle}
end
function SOCtoPSDCBridge{T}(instance, f, s::MOI.SecondOrderCone) where T
    d = MOI.dimension(s)
    cr = MOI.addconstraint!(instance, _SOCtoPSDCaff(f), MOI.PositiveSemidefiniteConeTriangle(d))
    SOCtoPSDCBridge(d, cr)
end

_SOCtoPSDCaff(f::MOI.VectorOfVariables) = _SOCtoPSDCaff(tofun(f))
_SOCtoPSDCaff(f::MOI.VectorAffineFunction) = _SOCtoPSDCaff(f, MOIU.eachscalar(f)[1])

MOI.supportsconstraint(::Type{SOCtoPSDCBridge{T}}, ::Type{<:Union{MOI.VectorOfVariables, MOI.VectorAffineFunction{T}}}, ::Type{MOI.SecondOrderCone}) where T = true
supportedconstrainttypes(::Type{SOCtoPSDCBridge{T}}) where T = [(MOI.VectorOfVariables, MOI.SecondOrderCone), (MOI.VectorAffineFunction{T}, MOI.SecondOrderCone)]
addedconstrainttypes(::Type{SOCtoPSDCBridge{T}}, ::Type{<:Union{MOI.VectorOfVariables, MOI.VectorAffineFunction{T}}}, ::Type{MOI.SecondOrderCone}) where T = [(MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle)]

function MOI.canget(instance::MOI.AbstractOptimizer, a::Union{MOI.ConstraintPrimal, MOI.ConstraintDual}, ::Type{SOCtoPSDCBridge{T}}) where T
    MOI.canget(instance, a, CI{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle})
end
function MOI.get(instance::MOI.AbstractOptimizer, a::MOI.ConstraintPrimal, c::SOCtoPSDCBridge)
    MOI.get(instance, a, c.cr)[trimap.(1:c.dim, 1)]
end
function MOI.get(instance::MOI.AbstractOptimizer, a::MOI.ConstraintDual, c::SOCtoPSDCBridge)
    dual = MOI.get(instance, a, c.cr)
    tdual = sum(i -> dual[trimap(i, i)], 1:c.dim)
    [tdual; dual[trimap.(2:c.dim, 1)]*2]
end

MOI.get(::SOCtoPSDCBridge{T}, ::MOI.NumberOfConstraints{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle}) where T = 1
MOI.get(b::SOCtoPSDCBridge{T}, ::MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle}) where T = [b.cr]

function MOI.delete!(instance::MOI.AbstractOptimizer, c::SOCtoPSDCBridge)
    MOI.delete!(instance, c.cr)
end

MOI.canmodifyconstraint(::MOI.AbstractOptimizer, ::SOCtoPSDCBridge, change) = false

"""
The `RSOCtoPSDCBridge` transforms the second order cone constraint ``\\lVert x \\rVert \\le 2tu`` with ``u \\ge 0`` into the semidefinite cone constraints
```math
\\begin{pmatrix}
  t & x^\\top\\\\
  x & 2uI
\\end{pmatrix} \\succeq 0
```
Indeed by the Schur Complement, it is positive definite iff
```math
\\begin{align*}
  uI & \\succ 0\\\\
  t - x^\\top (2uI)^{-1} x & \\succ 0
\\end{align*}
```
which is equivalent to
```math
\\begin{align*}
  u & > 0\\\\
  2tu & > x^\\top x
\\end{align*}
```
"""
struct RSOCtoPSDCBridge{T} <: AbstractBridge
    dim::Int
    cr::CI{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle}
end
MOI.supportsconstraint(::Type{RSOCtoPSDCBridge{T}}, ::Type{<:Union{MOI.VectorOfVariables, MOI.VectorAffineFunction{T}}}, ::Type{MOI.RotatedSecondOrderCone}) where T = true
supportedconstrainttypes(::Type{RSOCtoPSDCBridge{T}}) where T = [(MOI.VectorOfVariables, MOI.RotatedSecondOrderCone), (MOI.VectorAffineFunction{T}, MOI.RotatedSecondOrderCone)]
addedconstrainttypes(::Type{RSOCtoPSDCBridge{T}}, ::Type{<:Union{MOI.VectorOfVariables, MOI.VectorAffineFunction{T}}}, ::Type{MOI.RotatedSecondOrderCone}) where T = [(MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle)]
function RSOCtoPSDCBridge{T}(instance, f, s::MOI.RotatedSecondOrderCone) where T
    d = MOI.dimension(s)-1
    cr = MOI.addconstraint!(instance, _RSOCtoPSDCaff(f), MOI.PositiveSemidefiniteConeTriangle(d))
    RSOCtoPSDCBridge(d, cr)
end

_RSOCtoPSDCaff(f::MOI.VectorOfVariables) = _RSOCtoPSDCaff(tofun(f))
function _RSOCtoPSDCaff(f::MOI.VectorAffineFunction)
    n = length(f.constant)
    g = MOIU.eachscalar(f)[2]
    g = MOI.ScalarAffineFunction(g.variables, g.coefficients*2, g.constant*2)
    _SOCtoPSDCaff(MOIU.eachscalar(f)[[1; 3:n]], g)
end

function MOI.canget(instance::MOI.AbstractOptimizer, a::Union{MOI.ConstraintPrimal, MOI.ConstraintDual}, ::Type{RSOCtoPSDCBridge{T}}) where T
    MOI.canget(instance, a, CI{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle})
end
function MOI.get(instance::MOI.AbstractOptimizer, a::MOI.ConstraintPrimal, c::RSOCtoPSDCBridge)
    x = MOI.get(instance, MOI.ConstraintPrimal(), c.cr)[[trimap(1, 1); trimap(2, 2); trimap.(2:c.dim, 1)]]
    x[2] /= 2 # It is (2u*I)[1,1] so it needs to be divided by 2 to get u
    x
end
function MOI.get(instance::MOI.AbstractOptimizer, a::MOI.ConstraintDual, c::RSOCtoPSDCBridge)
    dual = MOI.get(instance, MOI.ConstraintDual(), c.cr)
    udual = sum(i -> dual[trimap(i, i)], 2:c.dim)
    [dual[1]; 2udual; dual[trimap.(2:c.dim, 1)]*2]
end

MOI.get(::RSOCtoPSDCBridge{T}, ::MOI.NumberOfConstraints{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle}) where T = 1
MOI.get(b::RSOCtoPSDCBridge{T}, ::MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{T}, MOI.PositiveSemidefiniteConeTriangle}) where T = [b.cr]

function MOI.delete!(instance::MOI.AbstractOptimizer, c::RSOCtoPSDCBridge)
    MOI.delete!(instance, c.cr)
end

MOI.canmodifyconstraint(::MOI.AbstractOptimizer, ::RSOCtoPSDCBridge, change) = false
