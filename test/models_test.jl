using Test
using EconoSim
using Agents

@testset "SuMSy contribution - none" begin
    model = create_sumsy_model(SuMSy(2000, 5000, 0.1, 10, seed = 500))
    actor = Actor()
    add_agent!(actor, model)

    run_econo_model!(model, 40)

    @test sumsy_balance(actor, model) == 8350
    @test !(:contribution_balance in keys(model.properties))
end

@testset "SuMSy contribution - fixed" begin
    model = create_sumsy_model(SuMSy(2000, 0, 0.1, 10),
                                fixed_contribution,
                                contribution_free = 0,
                                contribution_tiers = 0.2)
    actor = Actor()
    add_agent!(actor, model)

    book_asset!(actor.balance, SUMSY_DEP, 100, 0)

    econo_step!(model, 10)
    @test sumsy_balance(actor, model) == 2070
end

@testset "SuMSy contribution - on demand" begin
    model = create_sumsy_model(SuMSy(2000, 5000, 0.1, 10, seed = 500),
                        on_demand_contribution,
                        contribution_free = 0,
                        contribution_tiers = 0.1)
    actor = Actor()
    add_agent!(actor, model)

    request_contribution!(model, 100)
    econo_step!(model, 10)

    @test sumsy_balance(actor, model) == 2500
    @test sumsy_balance(model.contribution_balance, model) == 0
    @test model.contribution_shortage == 100

    request_contribution!(model, 100)
    econo_step!(model, 10)

    @test sumsy_balance(actor, model) == 4400
    @test sumsy_balance(model.contribution_balance, model) == 100
    @test model.contribution_shortage == 0

    request_contribution!(model, 500)
    econo_step!(model, 10)

    @test sumsy_balance(actor, model) == 5960
    @test sumsy_balance(model.contribution_balance, model) == 540
    @test model.contribution_shortage == 60

    request_contribution!(model, 1000)
    econo_step!(model, 10)

    @test sumsy_balance(actor, model) == 7268
    @test sumsy_balance(model.contribution_balance, model) == 1136
    @test model.contribution_shortage == 404
end
