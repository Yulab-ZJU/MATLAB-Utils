function varargout = image(varargin)
%IMAGE  Create image like `imagesc` using `pcolor`
%
% SYNTAX:
%   mu.image(I)
%   mu.image(x, y, I)
%   mu.image(ax, ...)

if isgraphics(varargin{1}, "axes")
    ax = varargin{1};
    varargin = varargin(2:end);
else
    ax = gca;
end

if isscalar(varargin)
    I = varargin{1};
    x = 1:size(I, 2);
    y = 1:size(I, 1);
elseif numel(varargin) == 3
    x = varargin{1};
    y = varargin{2};
    I = varargin{3};
else
    error('Invalid number of inputs');
end

validateattributes(x, 'numeric', {'vector'});
validateattributes(y, 'numeric', {'vector'});

if length(x) > 1
    dx = x(2) - x(1);
else
    dx = 1;
end
assert(all(diff(x) == dx), '[x] should be equally spaced.');

if length(y) > 1
    dy = y(2) - y(1);
else
    dy = 1;
end
assert(all(diff(y) == dy), '[y] should be equally spaced.');

X = [x - dx/2, x(end) + dx/2];
Y = [y - dy/2, y(end) + dy/2];
[X_grid, Y_grid] = meshgrid(X, Y);

% Pad matrix
I_padded = padarray(I, [1, 1], 0, 'post');

hold_state = ishold(ax);
h = pcolor(ax, X_grid, Y_grid, I_padded);

set(h, 'EdgeColor', 'none', 'FaceColor', 'flat'); % remove grids
set(ax, 'YDir', 'reverse');                       % match imagesc default
axis(ax, 'tight');
set(ax, 'XTick', x, 'YTick', y);

if ~hold_state
    hold(ax, hold_state);
end

if nargout > 0
    varargout{1} = h;
end

return;
end