function val = ifelse(cond, valTrue, valFalse)
% IFELSE  Ternary operator with optional lazy evaluation
%   val = mu.ifelse(cond, valTrue, valFalse)
%   - cond: logical scalar
%   - valTrue/valFalse: either a value or a function handle
if cond
    val = execute(valTrue);
else
    val = execute(valFalse);
end

return;
end

function out = execute(arg)
    if isa(arg, "function_handle")
        out = arg();
    else
        out = arg;
    end
    return;
end