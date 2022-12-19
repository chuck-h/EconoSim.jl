using DataStructures
using Intervals
using UUIDs
using Todo

SUMSY_DEP = BalanceEntry("SuMSy deposit")
SUMSY_DEBT = BalanceEntry("SuMSy debt")
SUMSY_DEM_FREE(id) = BalanceEntry(string(id, " demurrage free buffer"))

DemTiers = Vector{Tuple{Interval, Percentage}}
DemSettings = Union{DemTiers, Vector{<: Tuple{Real, Real}}, Real}

abstract type SuMSyParams end

"""
    struct SuMSy

Representation of the parameters of a SuMSy implementation.

* id: a unique id.
* guaranteed_income: the periodical guaranteed income.
* dem_free_buffer: the demurrage free buffer which is allocated to all accounts which have a right to a guaranteed income.
* dem_settings: the demurrage tiers. This is a list of tuples consisting of a lower bound and a demurrage percentage. The demurrage percentage is applied to the amounts above the lower bound up to the the next higher lower bound. If the demurrage free buffer of an account is larger than 0, all bounds are shifted up with this amount and no demurrage is applied to the amount up to the available demurrage free buffer.
The lower bound of the first tuple is always set to 0.
* interval: the interval after which demurrage is calculated and guaranteed income is dposited. If this interval is smaller than the period, partial demurrage and guaranteed income are applied. The scaling factor being equal to interval/period.
* seed: the amount whith which new accounts start.
* guaranteed_income_comment: The transaction comment for guaranteed income bookings.
* demurrage_comment: The transaction comment for demurrage bookings.
* net_income_comment: The transaction comment for net income bookings. These transactions combine demurrage and guaranteed income in one transaction.
* dep_entry: The balance entry used for depositing GI.
* dem_free_entry: The balance entry for the demurrage free buffer. Needs to change.
"""
mutable struct SuMSy <: SuMSyParams
    id::Symbol
    guaranteed_income::Currency
    dem_free::Currency
    dem_tiers::DemTiers
    interval::Int64
    seed::Currency
    seed_comment::String
    guaranteed_income_comment::String
    demurrage_comment::String
    net_income_comment::String
    dep_entry::BalanceEntry
    dem_free_entry::BalanceEntry
end

function SuMSy(id,
                guaranteed_income::Real,
                dem_free::Real,
                dem_settings::DemSettings,
                period::Integer;
                interval = period,
                seed::Real = 0,
                seed_comment = "Seed",
                guaranteed_income_comment = "Guaranteed income",
                demurrage_comment = "Demurrage",
                net_income_comment = "Net income",
                dep_entry = SUMSY_DEP,
                dem_free_entry = SUMSY_DEM_FREE(id))
    dem_tiers = make_tiers(dem_settings)

    if interval / period != 1
        guaranteed_income *= interval/period
        new_tiers = DemTiers()
                
        for tier in dem_tiers
            push!(new_tiers, (tier[1], tier[2] * interval / period))
        end

        dem_tiers = new_tiers
    end

    return SuMSy(Symbol(id),
                guaranteed_income,
                dem_free,
                dem_tiers,
                interval,
                seed,
                seed_comment,
                guaranteed_income_comment,
                demurrage_comment,
                net_income_comment,
                dep_entry,
                dem_free_entry)
end

"""
    SuMSy(guaranteed_income::Real,
            dem_free::Real,
            dem_settings::DemSettings,
            interval::Integer;
            seed::Real = 0,
            seed_comment = "Seed",
            guaranteed_income_comment = "Guaranteed income",
            demurrage_comment = "Demurrage",
            net_income_comment = "Net income",
            dep_entry = SUMSY_DEP,
            dem_free_entry = nothing)

Create a SuMSy struct with a default id. The id is set to :sumsy-uuid where uuid is generated by uuid4().
"""
function SuMSy(guaranteed_income::Real,
                dem_free::Real,
                dem_settings::DemSettings,
                period::Integer;
                interval::Integer = period,
                seed::Real = 0,
                seed_comment = "Seed",
                guaranteed_income_comment = "Guaranteed income",
                demurrage_comment = "Demurrage",
                net_income_comment = "Net income",
                dep_entry = SUMSY_DEP,
                dem_free_entry = nothing)
    id = string(:sumsy, "-", uuid4())

    if isnothing(dem_free_entry)
        dem_free_entry = SUMSY_DEM_FREE(id)
    end

    return SuMSy(id,
                guaranteed_income, dem_free, dem_settings, period,
                interval = interval,
                seed = seed,
                seed_comment = seed_comment,
                guaranteed_income_comment = guaranteed_income_comment,
                demurrage_comment = demurrage_comment,
                net_income_comment = net_income_comment,
                dep_entry = dep_entry,
                dem_free_entry = dem_free_entry)
end

"""
    SuMSyOverrides

SuMSy overrides to be used for individual balances.
"""
mutable struct SuMSyOverrides <: SuMSyParams
    sumsy_id::Symbol
    seed::Currency
    guaranteed_income::Currency
    dem_free::Currency
    dem_tiers::DemTiers
    SuMSyOverrides(sumsy_id::Symbol,
                    seed::Real,
                    guaranteed_income::Real,
                    dem_free::Real,
                    dem_settings::DemSettings) = new(
                        sumsy_id,
                        seed,
                        guaranteed_income,
                        dem_free,
                        make_tiers(dem_settings)
                        )
end

function sumsy_overrides(sumsy::SuMSy;
                        seed = sumsy.seed,
                        guaranteed_income = sumsy.guaranteed_income,
                        dem_free = sumsy.dem_free,
                        dem_tiers = sumsy.dem_tiers)
    return SuMSyOverrides(sumsy.id, seed, guaranteed_income, dem_free, dem_tiers)
end

"""
    make_tiers(dem_settings::Vector{T}) where  {T <: Tuple{Real, Real}}

Convert the vector of tuples into DemTiers.
The first interval always starts with 0, the last interval always has an unbounded upper bound. Tiers are sorted from low to high.
"""
function make_tiers(dem_settings::Vector{T}) where  {T <: Tuple{Real, Real}}
    sort!(dem_settings)
    tiers = DemTiers()
    lower_bound = 0
    demurrage = dem_settings[1][2]

    if length(dem_settings) > 1
        upper_bound = 0

        for index in 2:length(dem_settings)
            tuple = dem_settings[index]
            upper_bound = tuple[1]

            push!(tiers,
                (Interval{Currency, Open, Closed}(lower_bound, upper_bound),
                demurrage))

            lower_bound = upper_bound
            demurrage = tuple[2]
        end
    end

    push!(tiers,
        (Interval{Currency, Open, Unbounded}(lower_bound, nothing),
        demurrage))

    return tiers
end

make_tiers(demurrage_percentage::Real) = make_tiers([(0, demurrage_percentage)])

NO_DEM_TIERS = make_tiers([(0, 0)])
make_tiers(dem_tiers::DemTiers) = sort!(dem_tiers)

"""
    set_sumsy_active!(balance::Balance, sumsy::SuMSy, flag::Bool)

Indicate whether the balance participates in the specified SuMSy or not.
"""
function set_sumsy_active!(balance::Balance, sumsy::SuMSy, flag::Bool)
    if haskey(balance.properties, sumsy.id)
        balance.properties[sumsy.id][1] = flag
    else
        balance.properties[sumsy.id] = [flag, nothing]
    end
end

function is_sumsy_active(balance::Balance, sumsy::SuMSy)
    if haskey(balance.properties, sumsy.id)
        return balance.properties[sumsy.id][1]
    else
        return true
    end
end

function set_sumsy_overrides!(balance::Balance, overrides::SuMSyOverrides)
    if haskey(balance.properties, overrides.sumsy_id)
        balance.properties[overrides.sumsy_id][2] = overrides
    else
        balance.properties[overrides.sumsy_id] = [true, overrides]
    end

    return balance
end

function get_sumsy_overrides(balance::Balance, sumsy::SuMSy)
    if haskey(balance.properties, sumsy.id)
        return balance.properties[sumsy.id][2]
    else
        return nothing
    end
end

has_sumsy_overrides(balance::Balance, sumsy::SuMSy) = !isnothing(get_sumsy_overrides(balance, sumsy))

"""
    get_sumsy_params(balance::Balance, sumsy::SuMSy)

Returns sumsy if there are no overrides. Otherwise returns the overrides.
"""
function get_sumsy_params(balance::Balance, sumsy::SuMSy)
    overrides = get_sumsy_overrides(balance, sumsy)

    if isnothing(overrides)
        return sumsy
    else
        return overrides
    end
end

get_sumsy_params(balance::Balance, sumsy_overrides::SuMSyOverrides) = sumsy_overrides

function set_seed!(balance::Balance, sumsy::SuMSy, seed::Real)
    if has_sumsy_overrides(balance, sumsy)
            balance.properties[sumsy.id][2].seed = seed
    else
        balance.properties[sumsy.id] = [is_sumsy_active(balance, sumsy),
        sumsy_overrides(sumsy, seed = seed)]
    end

    return balance
end

function get_seed(balance::Balance, sumsy::SuMSy)
    if has_sumsy_overrides(balance, sumsy)
        return balance.properties[sumsy.id][2].seed
    else
        return sumsy.seed
    end
end

function set_guaranteed_income!(balance, sumsy::SuMSy, guaranteed_income::Real)
    if has_sumsy_overrides(balance, sumsy)
            balance.properties[sumsy.id][2].guaranteed_income = guaranteed_income
    else
        balance.properties[sumsy.id] = [is_sumsy_active(balance, sumsy),
        sumsy_overrides(sumsy, guaranteed_income = guaranteed_income)]
    end

    return balance
end

function get_guaranteed_income(balance::Balance, sumsy::SuMSy)
    if has_sumsy_overrides(balance, sumsy)
        return balance.properties[sumsy.id][2].guaranteed_income
    else
        return sumsy.guaranteed_income
    end
end

todo"Move demurrage free buffer off balance sheet."
function set_initial_dem_free!(balance::Balance, sumsy::SuMSy, dem_free::Real)
    if has_sumsy_overrides(balance, sumsy)
        balance.properties[sumsy.id][2].dem_free = dem_free
    else
        balance.properties[sumsy.id] = [is_sumsy_active(balance, sumsy),
        sumsy_overrides(sumsy, dem_free = dem_free)]
    end

    book_asset!(balance, sumsy.dem_free_entry, dem_free, set_to_value = true)

    return balance
end

"""
    get_initial_dem_free(balance::Balance, sumsy::SuMSy)

Returns the initial size of the demurrage free buffer.
"""
function get_initial_dem_free(balance::Balance, sumsy::SuMSy)
    if has_sumsy_overrides(balance, sumsy)
        return balance.properties[sumsy.id][2].dem_free
    else
        return sumsy.dem_free
    end
end

function book_dem_free!(balance::Balance, sumsy::SuMSy)
    if !has_asset(balance, sumsy.dem_free_entry)
        book_asset!(balance, sumsy.dem_free_entry, get_initial_dem_free(balance, sumsy))
    end
end

function get_dem_free(balance::Balance, sumsy::SuMSy)
    # Make sure the balanceentry exists
    book_dem_free!(balance, sumsy)

    return asset_value(balance, sumsy.dem_free_entry)
end

"""
    transfer_dem_free!(source::Balance, destination::Balance, amount::Real)

Transfer a part or all of the demurrage free buffer from one balance to another. No more than the available demurrage free buffer can be transferred.
* source::Balance - the balance from which the demurrage free amount is taken.
* destination::Balance - the balance to which the demurrage free buffer is transferred.
* amount::Real - the amount to be transferred.
* return - whether or not the transaction was succesful.
"""
function transfer_dem_free!(source::Balance,
                            destination::Balance,
                            sumsy::SuMSy,
                            amount::Real,
                            timestamp::Int = 0;
                            comment = "Demurrage free buffer transfer")
    # Make sure the balance entries exist
    book_dem_free!(source, sumsy)
    book_dem_free!(destination, sumsy)

    return transfer_asset!(source, destination, sumsy.dem_free_entry, amount,
                            timestamp, comment = comment)
end

function set_dem_tiers!(balance::Balance, sumsy::SuMSy, dem_settings::DemSettings)
    dem_tiers = make_tiers(dem_settings)

    if has_sumsy_overrides(balance, sumsy)
            balance.properties[sumsy.id][2].dem_tiers = dem_tiers
    else
        balance.properties[sumsy.id] = [is_sumsy_active(balance, sumsy),
        sumsy_overrides(sumsy, dem_tiers = dem_tiers)]
    end

    return balance
end

function get_dem_tiers(balance::Balance, sumsy::SuMSy)
    if has_sumsy_overrides(balance, sumsy)
        return balance.properties[sumsy.id][2].dem_tiers
    else
        return sumsy.dem_tiers
    end
end

function sumsy_balance(balance::Balance, sumsy::SuMSy)
    return asset_value(balance, sumsy.dep_entry)
end

function sumsy_balance(balance::Balance, sumsy::SuMSy, step::Int)
    return sumsy_balance(balance, sumsy) + calculate_partial_guaranteed_income(sumsy, step) - calculate_demurrage(balance, sumsy, step)
end

function calculate_partial_guaranteed_income(sumsy_params::SuMSyParams, step::Int)
    period = mod(step, sumsy_params.interval) == 0 ? sumsy_params.interval : mod(step, sumsy_params.interval)

    return Currency(sumsy_params.guaranteed_income * period / sumsy_params.interval)
end

"""
    transfer_sumsy!(source::Balance,
                    destination::Balance,
                    sumsy::SuMSy,
                    amount::Real,
                    timestamp::Int = 0;
                    comment = "")

Transfer an amount of SuMSy money from one balance sheet to another. No more than the available amount of money can be transferred.
Negative amounts result in a transfer from destination to source.
"""
function transfer_sumsy!(source::Balance,
                            destination::Balance,
                            sumsy::SuMSy,
                            amount::Real,
                            timestamp::Int = 0;
                            comment = "")
    if amount > 0
        amount = min(amount, sumsy_balance(source, sumsy))
    else
        amount = min(-amount, sumsy_balance(destination, sumsy))
    end

    transfer_asset!(source, destination, sumsy.dep_entry, amount, timestamp, comment = comment)
end

"""
    calculate_demurrage(balance::Balance, sumsy::SuMSy, step::Int)

Calculates the demurrage due at the current timestamp. This is not restricted to timestamps which correspond to multiples of the interval.
"""
function calculate_demurrage(balance::Balance, sumsy_params::SuMSyParams, step::Int)
    transactions = balance.transaction_log
    cur_balance = sumsy_balance(balance, sumsy_params)
    period = mod(step, sumsy_params.interval) == 0 ? sumsy_params.interval : mod(step, sumsy_params.interval)
    period_start = step - period
    weighted_balance = 0
    i = length(transactions)
    t_step = step

    while i > 0 && transactions[i].timestamp >= period_start
        t_step = transactions[i].timestamp
        amount = 0

        while i > 0 && transactions[i].timestamp == t_step
            t = transactions[i]

            for transaction in t.transactions
                if transaction.type == asset && transaction.entry == sumsy_params.dep_entry
                    amount += transaction.amount
                end
            end

            i -= 1
        end

        weighted_balance += (step - t_step) * cur_balance
        step = t_step
        cur_balance -= amount
    end

    if t_step > period_start
        weighted_balance += (t_step - period_start) * cur_balance
    end

    return calculate_demurrage(weighted_balance / period, get_sumsy_params(balance, sumsy_params), fraction = period / sumsy_params.interval)
end

function calculate_demurrage(avg_balance::Currency, sumsy_params::SuMSyParams, subtract_dem_free = true; fraction::Real = 1.0)
    if subtract_dem_free
        avg_balance = max(0, avg_balance - sumsy_params.dem_free)
    end

    demurrage = 0

    for tier in sumsy_params.dem_tiers
        if avg_balance <= 0
            break
        else
            if is_right_unbounded(tier[1])
                amount = avg_balance
                avg_balance = 0
            else
                amount = min(span(tier[1]), avg_balance)
                avg_balance -= amount
            end

            demurrage += amount * tier[2]
        end
    end

    return Currency(demurrage * fraction)
end

function telo(sumsy_params::SuMSyParams)
    return telo(sumsy_params.guaranteed_income, sumsy_params.dem_free, sumsy_params.dem_tiers)
end

function telo(income::Real, dem_free::Real, dem_settings::DemSettings)
    return telo(Currency(income), Currency(dem_free), make_tiers(dem_settings))
end

function telo(income::Currency, dem_free::Currency, dem_tiers::DemTiers)
    total_dem = 0
    telo = 0

    for tier in dem_tiers
        if is_right_unbounded(tier[1]) || total_dem + span(tier[1]) * tier[2] > income
            if tier[2] != 0
                telo += (income - total_dem) / tier[2]
            else
                telo = CUR_MAX
            end
            
            break
        else
            telo += span(tier[1])
            total_dem += span(tier[1]) * tier[2]
        end
    end

    return Currency(telo + dem_free)
end

function time_telo(sumsy::SuMSy, balance::Balance = Balance())
    sumsy_params = get_sumsy_params(balance, sumsy)
    t = 0
    eq = telo(sumsy_params)

    while asset_value(balance, SUMSY_DEP) < eq - 1
        dem = calculate_demurrage(balance, sumsy_params, 0)
        book_asset!(balance, SUMSY_DEP, sumsy_params.guaranteed_income - dem)
        t += 1
    end

    return t
end

"""
    process_ready(sumsy::SuMSy, step::Int)

Check whether processing needs to be done.
"""
process_ready(sumsy::SuMSy, step::Int) = mod(step, sumsy.interval) == 0

function book_net_result!(balance::Balance, sumsy::SuMSy, seed::Currency, guaranteed_income::Currency, demurrage::Currency, step::Integer)    
    book_asset!(balance, sumsy.dep_entry, seed + guaranteed_income - demurrage, step, comment = sumsy.net_income_comment)
end

function book_atomic_results!(balance::Balance, sumsy::SuMSy, seed::Currency, guaranteed_income::Currency, demurrage::Currency, step::Integer)
    if step == 0
        book_asset!(balance, sumsy.dep_entry, seed, step, comment = sumsy.seed_comment)
    end

    book_asset!(balance, sumsy.dep_entry, guaranteed_income, step, comment = sumsy.guaranteed_income_comment)
    book_asset!(balance, sumsy.dep_entry, -demurrage, step, comment = sumsy.demurrage_comment)
end

function book_nothing(balance::Balance, sumsy::SuMSy, seed::Currency, guaranteed_income::Currency, demurrage::Currency, step::Integer)
end

"""
    process_sumsy!(balance::Balance, sumsy::SuMSy, step::Int)

Processes demurrage and guaranteed income if the timestamp is a multiple of the SuMSy interval. Otherwise this function does nothing. Returns the deposited guaranteed income amount and the subtracted demurrage. When this function is called with timestamp == 0, the balance will be 'seeded'. The seed amount is added to the returned income.

* sumsy: the SuMSy implementation to use for calculations.
* balance: the balance on which to apply SuMSy.
* timestamp: the current timestamp. Used to determine whether action needs to be taken.
"""
function process_sumsy!(balance::Balance, sumsy::SuMSy, step::Int; booking_function = book_net_result!)
   if is_sumsy_active(balance, sumsy) && process_ready(sumsy, step)
        seed = step == 0 ? get_seed(balance, sumsy) : CUR_0
        income = get_guaranteed_income(balance, sumsy)
        demurrage = calculate_demurrage(balance, sumsy, step)
        booking_function(balance, sumsy, seed, income, demurrage, step)

        return seed, income, demurrage
   else
        return CUR_0, CUR_0, CUR_0
   end
end

function sumsy_loan(creditor::Balance,
            debtor::Balance,
            amount::Real,
            installments::Integer,
            interval = 1,
            timestamp::Int64 = 0;
            interest_rate::Real = 0,
            money_entry::BalanceEntry = SUMSY_DEP,
            debt_entry::BalanceEntry = SUMSY_DEBT)
    return borrow(creditor, debtor, amount, interest_rate, installments, interval, timestamp, bank_loan = false, negative_allowed = false, money_entry = money_entry, debt_entry = debt_entry)
end
