function test_noc(bridged_mock, F, S, n)
    @test MOI.get(bridged_mock, MOI.NumberOfConstraints{F, S}()) == n
    @test length(MOI.get(bridged_mock, MOI.ListOfConstraintIndices{F, S}())) == n
    @test ((F, S) in MOI.get(bridged_mock, MOI.ListOfConstraints())) == !iszero(n)
end

# Test deletion of bridge
function test_delete_bridge(
    m::MOIB.AbstractBridgeOptimizer, ci::MOI.ConstraintIndex{F, S}, nvars::Int,
    nocs::Tuple; used_bridges = 1, num_bridged = 1) where {F, S}
    function num_bridges()
        return count(bridge -> true, values(MOIB.Constraint.bridges(m)))
    end
    start_num_bridges = num_bridges()
    @test MOI.get(m, MOI.NumberOfVariables()) == nvars
    @test length(MOI.get(m, MOI.ListOfVariableIndices())) == nvars
    test_noc(m, F, S, num_bridged)
    for noc in nocs
        test_noc(m, noc...)
    end
    @test MOI.is_valid(m, ci)
    MOI.delete(m, ci)
    @test_throws MOI.InvalidIndex(ci) MOI.delete(m, ci)
    @test !MOI.is_valid(m, ci)
    @test num_bridges() == start_num_bridges - used_bridges
    test_noc(m, F, S, num_bridged - 1)
    # As the bridge has been removed, if the constraints it has created where not removed, it wouldn't be there to decrease this counter anymore
    @test MOI.get(m, MOI.NumberOfVariables()) == nvars
    @test length(MOI.get(m, MOI.ListOfVariableIndices())) == nvars
    for noc in nocs
        test_noc(m, noc...)
    end
end
function test_delete_bridged_variable(
    m::MOIB.AbstractBridgeOptimizer, vi::MOI.VariableIndex, S::Type,
    nvars::Int, nocs::Tuple; used_bridges = 1, num_bridged = 1, used_constraints = 1)
    function num_bridges()
        return count(bridge -> true, values(MOIB.Variable.bridges(m)))
    end
    start_num_bridges = num_bridges()
    @test MOI.get(m, MOI.NumberOfVariables()) == nvars
    @test length(MOI.get(m, MOI.ListOfVariableIndices())) == nvars
    if S != MOI.Reals
        F = S <: MOI.AbstractScalarSet ? MOI.SingleVariable : MOI.VectorOfVariables
        test_noc(m, F, S, num_bridged)
    end
    for noc in nocs
        test_noc(m, noc...)
    end
    @test MOI.is_valid(m, vi)
    MOI.delete(m, vi)
    @test_throws MOI.InvalidIndex(vi) MOI.delete(m, vi)
    @test !MOI.is_valid(m, vi)
    @test num_bridges() == start_num_bridges - used_bridges
    if S != MOI.Reals
        test_noc(m, F, S, num_bridged - used_constraints)
    end
    @test MOI.get(m, MOI.NumberOfVariables()) == nvars - 1
    @test length(MOI.get(m, MOI.ListOfVariableIndices())) == nvars - 1
    for noc in nocs
        test_noc(m, noc...)
    end
end
function test_delete_bridged_variables(
    m::MOIB.AbstractBridgeOptimizer, vis::Vector{MOI.VariableIndex}, S::Type,
    nvars::Int, nocs::Tuple; used_bridges = 1, num_bridged = 1)
    function num_bridges()
        return count(bridge -> true, values(MOIB.Variable.bridges(m)))
    end
    start_num_bridges = num_bridges()
    @test MOI.get(m, MOI.NumberOfVariables()) == nvars
    @test length(MOI.get(m, MOI.ListOfVariableIndices())) == nvars
    if S != MOI.Reals
        F = S <: MOI.AbstractScalarSet ? MOI.SingleVariable : MOI.VectorOfVariables
        test_noc(m, F, S, num_bridged)
    end
    for noc in nocs
        test_noc(m, noc...)
    end
    @test all(vi -> MOI.is_valid(m, vi), vis)
    MOI.delete(m, vis)
    @test_throws MOI.InvalidIndex(vis[1]) MOI.delete(m, vis)
    @test all(vi -> !MOI.is_valid(m, vi), vis)
    @test num_bridges() == start_num_bridges - used_bridges
    if S != MOI.Reals
        test_noc(m, F, S, num_bridged - 1)
    end
    @test MOI.get(m, MOI.NumberOfVariables()) == nvars - length(vis)
    @test length(MOI.get(m, MOI.ListOfVariableIndices())) == nvars - length(vis)
    for noc in nocs
        test_noc(m, noc...)
    end
end
