function val = ifelse(cond, valTrue, valFalse)
%IFELSE  Ternary operator with optional lazy evaluation.
%
% SYNTAX
%   val = mu.ifelse(cond, valTrue, valFalse)
%
% INPUTS:
%     cond              - logical scalar
%     valTrue/valFalse  - either a value or a function handle
%
% OUTPUTS:
%     val  - output value
%
% NOTES:
%   - If valTrue/valueFalse is an expression and not expected to be calculated before
%     passing the if-else operator, use function handle as inputs. (e.g., @() expression)

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