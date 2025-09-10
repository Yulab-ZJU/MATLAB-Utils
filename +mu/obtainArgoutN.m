function varargout = obtainArgoutN(fcn, Ns, varargin)
%OBTAINARGOUTN  Return specific outputs of a function handle.
%
% SYNTAX:
%     [out1, out2, ...] = mu.obtainArgoutN(fcn, Ns, varargin)
%
% INPUTS:
%     fcn       - function handle
%     Ns        - vector of desired output positions
%     varargin  - inputs to fcn
%
% OUTPUTS:
%     varargout - outputs from fcn
%
% EXAMPLES:
%     [res1,res2] = mu.obtainArgoutN(@size, [2,3], ones(10,20,30));
%     >> res1 = 20, res2 = 30

nMax = max(Ns);          % total number of outputs to request
allOut = cell(1, nMax);  % preallocate cell for all outputs

% Call function once, get all outputs up to max(Ns)
[allOut{:}] = fcn(varargin{:});

% Extract requested outputs
nReq = numel(Ns);
varargout = cell(1, nReq);
for k = 1:nReq
    varargout{k} = allOut{Ns(k)};
end

return;
end
