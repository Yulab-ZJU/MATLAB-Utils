function x = uniformSymmetricJitter(x0, jitter, sz)
% Uniform symmetric 1D jitter around x0
%
% x = uniformSymmetricJitter(x0, jitter, sz)
%
% jitter : full width (like XJitterWidth)
% sz     : output size, e.g. [n 1]

n = prod(sz);

if n <= 1 || jitter <= 0
    x = repmat(x0, sz);
    return;
end

% generate symmetric offsets: 0, +d, -d, +2d, -2d, ...
k = (0:n-1).';
order = zeros(n,1);
order(1) = 0;
idx = 2;
for i = 1:ceil((n-1)/2)
    if idx <= n, order(idx) =  i; idx = idx+1; end
    if idx <= n, order(idx) = -i; idx = idx+1; end
end

% spacing so that max offset ~= jitter/2
d = jitter / max(1, 2*max(abs(order)));
dx = order * d;

x = reshape(x0 + dx, sz);

return;
end
