function B = lcm(A)
% Vectorized least common multiple for real vector A with tolerance
% B satisfies all(abs(A./B - round(A./B)) < 1e-12), minimal positive B

tol = 1e-12;
maxDenominator = 1e9;

validateattributes(A, {'numeric'}, {'vector', 'real', 'nonempty'});

[n, d] = arrayfun(@(x) rat_with_limit(x, tol, maxDenominator), A);

L = reduce_lcm(d);
C = round(n .* (L ./ d));
M = reduce_lcm(C);
B = M / L;

% Validate
ratios = B ./ A;
diffs = abs(ratios - round(ratios));
if any(diffs > tol)
    warning('Computed lcm exceeds tolerance.');
end

return;
end

%% 
function [n, d] = rat_with_limit(x, tol, maxDen)
    [n, d] = rat(x, tol);
    if d > maxDen
        error('Number too irrational to approximate with given tolerance.');
    end
end

function r = reduce_lcm(v)
    % vectorized lcm using reduce pattern
    v = v(:);
    r = v(1);
    for k = 2:numel(v)
        r = lcm(r, v(k));
    end
end
