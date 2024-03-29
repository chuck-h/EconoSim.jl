using Agents

"""
    behavior_vector(behaviors::Union{Nothing, Function, Vector{Function}})

Create a Vector of functions based on the input.
If nothing is passed, an empty vector is returned.
If a function is passed, a vector with one element is returned.
If a vector is passed, the vector itself is returned.
"""
function behavior_vector(behaviors::Union{Nothing, Function, Vector{Function}})
    if behaviors isa Function
        return Vector{Function}([behaviors])
    elseif behaviors isa Vector
        return Vector{Function}(behaviors)
    else
        return Vector{Function}()
    end
end

function create_properties(model_behaviors::Union{Nothing, Function, Vector{Function}})
    properties = Dict{Symbol, Any}()
    properties[:id_counter] = 0
    properties[:step] = 0
    properties[:model_behaviors] = behavior_vector(model_behaviors)

    return properties
end

"""
    create_econo_model(model_behaviors::Union{Nothing, Function, Vector{Function}} = nothing)

Create a default model with 0 or more model behavior functions.
Each cycle the model runs, all model behavior functions are called in order.
"""
function create_econo_model(actor_type::Type = MonetaryActor, model_behaviors::Union{Nothing, Function, Vector{Function}} = nothing)
    return StandardABM(actor_type, properties = create_properties(model_behaviors))
end

function create_unremovable_econo_model(actor_type::Type = MonetaryActor, model_behaviors::Union{Nothing, Function, Vector{Function}} = nothing)
    return UnremovableABM(actor_type, properties = create_properties(model_behaviors))
end

function next_id(model::ABM)
    model.id_counter += 1

    return model.id_counter
end

function add_actor!(model::ABM, actor::AbstractActor)
    actor.id = next_id(model)
    add_agent!(actor, model)

    return actor
end

has_model_behavior(model, behavior::Function) = behavior in model.model_behaviors
add_model_behavior!(model, behavior::Function) = (push!(model.model_behaviors, behavior); model)
delete_model_behavior!(model, behavior::Function) = (delete_element!(model.model_behaviors, behavior); model)
clear_model_behaviors(model) = (empty!(model.model_behaviors); model)

get_step(model) = model.step

function econo_model_step!(model::ABM)
    for behavior in model.model_behaviors
        behavior(model)
    end
end

"""
    function stepper!(model::ABM, step::Integer)

    This function makes sure the econo_model_step! and actor_step! functions have access to the current step of the model.
"""
function stepper!(model::ABM, step::Integer)
    model.step += 1

    return step >= model.run_steps
end

function econo_step!(model::ABM, steps::Integer = 1, actors_first::Bool = false)
    model.properties[:run_steps] = steps

    step!(model, actor_step!, econo_model_step!, stepper!, actors_first)
end

function run_econo_model!(model::ABM, steps::Integer, actors_first = false; kwargs...)
    model.properties[:run_steps] = steps

    run!(model, actor_step!, econo_model_step!, stepper!, agents_first = actors_first; kwargs...)
end

