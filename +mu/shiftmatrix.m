function Y = shiftmatrix(X, N, opt)
% SHIFTMATRIX - Shift a 2-D matrix by [Nlr, Nud] and pad with specified method.
%
% Y = mu.shiftmatrix(X, N, opt)
%
% INPUTS:
%     X   : 2D numeric matrix
%     N   : 1x2 integer vector [Nlr, Nud]
%           N(1) > 0 => shift right, < 0 => shift left
%           N(2) > 0 => shift up,    < 0 => shift down
%     opt : 'zero', 'replicate', 'loop' (optional, default: 'zero')
%
% OUTPUT:
%     Y   : shifted matrix (same size as X)
% 
% EXMAPLE:
%     X = reshape(1:16, 4, 4)
%     mu.shiftmatrix(X, [1, 0], 'zero')       % shift right 1
%     mu.shiftmatrix(X, [-1, 0], 'replicate') % shift left 1 with edge fill
%     mu.shiftmatrix(X, [0, 1], 'loop')       % shift up 1 (circular)
%     mu.shiftmatrix(X, [1, 1], 'zero')       % shift right-up 1

% --- Input validation ---
mIp = inputParser;
mIp.addRequired('X', @(x) validateattributes(x, {'numeric'}, {'2d'}));
mIp.addRequired('N', @(x) validateattributes(x, {'numeric'}, {'integer', 'numel', 2}));
mIp.addOptional('opt', 'zero', @(x) any(validatestring(x, {'zero', 'replicate', 'loop'})));
mIp.parse(X, N, opt);
opt = mIp.Results.opt;

[a, b] = size(X);
Nlr = N(1);  % left/right (columns)
Nud = N(2);  % up/down (rows)

% Initialize output
Y = zeros(a, b);

padrow = abs(Nud);  % row padding
padcol = abs(Nlr);  % column padding
rowStart = 1 + padrow + Nud;
colStart = 1 + padcol - Nlr;

switch opt
    case 'zero'
        padded = padarray(X, [padrow, padcol], 0, 'both');
        Y = padded(rowStart : rowStart + a - 1, ...
                   colStart : colStart + b - 1);
    case 'replicate'
        padded = padarray(X, [padrow, padcol], 'replicate', 'both');
        Y = padded(rowStart : rowStart + a - 1, ...
                   colStart : colStart + b - 1);
    case 'loop'
        Y = circshift(X, [-Nud, Nlr]);
end

return;
end