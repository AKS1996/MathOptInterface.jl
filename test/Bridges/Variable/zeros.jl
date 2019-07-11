using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MathOptInterface.Test
const MOIU = MathOptInterface.Utilities
const MOIB = MathOptInterface.Bridges

include("../utilities.jl")

mock = MOIU.MockOptimizer(MOIU.Model{Float64}())
config = MOIT.TestConfig()

@testset "NonposToNonneg" begin
    bridged_mock = MOIB.Variable.Zeros{Float64}(mock)

    MOIU.set_mock_optimize!(mock,
        (mock::MOIU.MockOptimizer) -> MOIU.mock_optimize!(
            mock, [1.0],
            (MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}) => 0.0,
            (MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}) => 1.0)
    )

    x, cx = MOI.add_constrained_variable(bridged_mock, MOI.GreaterThan(0.0))
    yz, cyz = MOI.add_constrained_variables(bridged_mock, MOI.Zeros(2))
    y, z = yz
    fx = MOI.SingleVariable(x)
    fy = MOI.SingleVariable(y)
    fz = MOI.SingleVariable(z)
    c1 = MOI.add_constraint(bridged_mock, 1.0fy + 1.0fz, MOI.EqualTo(0.0))
    c2 = MOI.add_constraint(bridged_mock, 1.0fx + 1.0fy + 1.0fz, MOI.GreaterThan(1.0))
    MOI.set(bridged_mock, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    obj = 1.0fx - 1.0fy - 1.0fz
    MOI.set(bridged_mock, MOI.ObjectiveFunction{typeof(obj)}(), obj)

    err = ErrorException(
        "Cannot unbridge function because some variables are bridged by" *
        " variable bridges that do not support reverse mapping, e.g.," *
        " `ZerosBridge`."
    )
    @test_throws err MOI.get(bridged_mock, MOI.ObjectiveFunction{typeof(obj)}())
    # With `c1`, the function does not contain any variable so it tests that it
    # also throws an error even if it never calls `variable_unbridged_function`.
    @test_throws err MOI.get(bridged_mock, MOI.ConstraintFunction(), c1)
    @test_throws err MOI.get(bridged_mock, MOI.ConstraintFunction(), c2)

    MOI.optimize!(bridged_mock)
    @test MOI.get(bridged_mock, MOI.VariablePrimal(), x) == 1.0
    @test MOI.get(bridged_mock, MOI.VariablePrimal(), y) == 0.0
    @test MOI.get(bridged_mock, MOI.VariablePrimal(), z) == 0.0

    @test MOI.get(bridged_mock, MOI.ConstraintDual(), cx) == 0.0
    @test MOI.get(bridged_mock, MOI.ConstraintDual(), c1) == 0.0
    @test MOI.get(bridged_mock, MOI.ConstraintDual(), c2) == 1.0

    err = ArgumentError(
        "Bridge of type `MathOptInterface.Bridges.Variable.ZerosBridge{Float64}`" *
        " does not support accessing the attribute" *
        " `MathOptInterface.ConstraintDual(1)`."
    )
    @test_throws err MOI.get(bridged_mock, MOI.ConstraintDual(), cyz)

    @test MOI.get(mock, MOI.NumberOfVariables()) == 1
    @test MOI.get(mock, MOI.ListOfVariableIndices()) == [x]
    @test MOI.get(bridged_mock, MOI.NumberOfVariables()) == 3
    @test MOI.get(bridged_mock, MOI.ListOfVariableIndices()) == [x, y, z]
    @test MOI.get(mock, MOI.NumberOfConstraints{MOI.VectorOfVariables, MOI.Zeros}()) == 0
    @test MOI.get(bridged_mock, MOI.NumberOfConstraints{MOI.VectorOfVariables, MOI.Zeros}()) == 1
    @test MOI.get(bridged_mock, MOI.ListOfConstraintIndices{MOI.VectorOfVariables, MOI.Zeros}()) == [cyz]
end
