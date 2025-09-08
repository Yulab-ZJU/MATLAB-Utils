function [tf, ME] = isTextScalar(s)
% ISTEXTSCALAR  Check if input is a text scalar
%   [tf, ME] = mu.isTextScalar(s)
%   - tf: logical true if s is a text scalar, false otherwise
%   - ME: MException object if check fails, empty otherwise

try
    mustBeTextScalar(s);
    tf = true;
    ME = [];
catch ME
    tf = false;
end

return;
end