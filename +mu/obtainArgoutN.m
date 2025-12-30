function varargout = obtainArgoutN(fcn, Ns, varargin)
%OBTAINARGOUTN  Return specific outputs of a function handle
%               without forcing computation of unused outputs.
%
% SYNTAX:
%     [out1, out2, ...] = mu.obtainArgoutN(fcn, Ns, varargin)
%
% NOTES:
%   - fcn is called once per requested output
%   - Each call uses nargout == 1
%   - Extra outputs are never computed inside fcn

nReq = numel(Ns);
varargout = cell(1, nReq);

for k = 1:nReq
    % wrapper forces single-output evaluation
    out = nthOutput(fcn, Ns(k), varargin{:});

    varargout{k} = out;
end

return;
end

function out = nthOutput(fcn, idx, varargin)
    % Force fcn to see nargout == idx, but only return one output
    tmp = cell(1, idx);
    [tmp{:}] = fcn(varargin{:});
    out = tmp{idx};
end
