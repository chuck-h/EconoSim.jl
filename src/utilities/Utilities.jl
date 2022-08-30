
include("types.jl")
export Percentage, Health, value, num_entities
export Fixed, Currency
export LeftInterval, RightInterval, ClosedInterval
export Prices

include("functions.jl")
export extract, delete_element!
export is_left_closed, is_right_closed, is_left_open, is_right_open, is_left_unbounded, is_right_unbounded

include("constants.jl")
export INF, CUR_MIN, CUR_MAX, CUR_0
