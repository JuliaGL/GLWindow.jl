macro enum(T,syms...)
    blk = quote
        immutable $(esc(T))
            n::Int32
            function $(esc(T))(n::Integer)
                if n > length($syms)
                    error("enum ", $T, " is only defined in the range from 0 to ", $(length(syms)))
                end
                new(n)
            end
        end
        Base.show(io::IO, x::$(esc(T))) = print(io, $syms[x.n+1])
        Base.show(io::IO, x::Type{$(esc(T))}) = print(io, $(string("enum ", T, ' ', '(', join(syms, ", "), ')')))
    end
    for (i,sym) in enumerate(syms)
        push!(blk.args, :(const $(esc(sym)) = $(esc(T))($(i-1))))
    end
    push!(blk.args, :nothing)
    blk.head = :toplevel
    return blk
end
