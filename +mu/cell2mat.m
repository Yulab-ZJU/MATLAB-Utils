function A = cell2mat(C)
% Elements of C can be cell/string/numeric

[a, b] = size(C);

if a == 1 % for row vector
    A = cat(2, C{:});
elseif b == 1 % for column vector
    A = cat(1, C{:});
else % for 2-D
    temp = mu.rowfun(@(x) cat(2, x{:}), C, "UniformOutput", false);
    A = cat(1, temp{:});
end

return;
end