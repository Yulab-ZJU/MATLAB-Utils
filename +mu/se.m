function E = se(x, varargin)
%SE  Standard error of [x] along [dim].
%
% SYNTAX:
%     E = mu.se(x)
%     E = mu.se(x, dim)
%     E = mu.se(x, dim, "omitnan")

mIp = inputParser;
mIp.addRequired("x");
mIp.addOptional("dim", [], @(x) (mu.isTextScalar(x) && (strcmpi(x, 'all')) || (x > 0 && fix(x) == x)));
mIp.addOptional("omitnan", "omitnan", @(x) strcmpi(x, 'omitnan'));
mIp.parse(x, varargin{:})

dim = mIp.Results.dim;
omitnan = strcmpi(mIp.Results.omitnan, 'omitnan');

if isempty(dim)
    if omitnan
        stdVal = std(x, [], "omitnan");
        nX = sum(~isnan(x));
    else
        stdVal = std(x);
        nX = sum(ones(size(x)));
    end
else
    if omitnan
        stdVal = std(x, [], dim, "omitnan");
        nX = sum(~isnan(x), dim);
    else
        stdVal = std(x, [], dim);
        nX = size(x, dim);
    end
end

E = stdVal ./ sqrt(nX);
return;
end