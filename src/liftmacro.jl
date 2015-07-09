macro ^(call, T...)
    arg_cache = Dict{Union{Symbol, Expr}, Expr}()
    # if !(isa(call, Expr)) || call.head != :call
    #     throw(ArgumentError("@^: argument must be a function call"))
    # end

    if length(T) == 1
        e_type = T[1]
    else
        throw(ArgumentError("@^: wrong number of arguments"))
    end

    e_call = gen_calls(call, arg_cache, true)
    args = collect(keys(arg_cache))
    e_nullcheck = :($(args[1]).isnull)
    for i = 2:length(args)
        e_nullcheck = Expr(:||, e_nullcheck, :($(args[i]).isnull))
    end

    res = quote
        if $e_nullcheck
            Nullable{$e_type}()
        else
            $e_call
        end
    end
    return esc(res)
end

# base case for literals
gen_calls(e, arg_cache, top) = e

# base case for symbols
function gen_calls(e::Symbol, arg_cache, top)
    new_arg = get!(arg_cache, e, :($e.value))
    return new_arg
end

# recursively modify expression tree
function gen_calls(e::Expr, arg_cache, top)
    if e.head == :call
        if top == true
            res = Expr(:call, e.args[1], gen_calls(e.args[2:end], arg_cache, false)...)
            return :(Nullable($res))
        else
            return Expr(:call, e.args[1], gen_calls(e.args[2:end], arg_cache, false)...)
        end
    elseif e.head == :ref
        new_arg = get!(arg_cache, e, :($e.value))
        return new_arg
    # `if` support
    elseif e.head == :if
        return Expr(:if, [ gen_calls(expr, arg_cache, top) for expr in e.args ]...)
    elseif e.head == :block
        return Expr(:block, [ gen_calls(expr, arg_cache, top) for expr in e.args ]...)
    elseif e.head == :comparison
        return Expr(:comparison, gen_calls(e.args[1], arg_cache, top), e.args[2], gen_calls(e.args[3], arg_cache, top))
    # /if support
    else
        return e
    end
end

# recursive case for `args` field arrays
function gen_calls(args::Array, arg_cache, top)
    return [ gen_calls(arg, arg_cache, top) for arg in args ]
end
