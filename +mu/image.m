function varargout = image(varargin)
%IMAGE Create image-like plot using pcolor, supporting non-uniform spacing
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

if numel(varargin) == 1
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

x = x(:)'; 
y = y(:)';

X = calculate_bounds(x);
Y = calculate_bounds(y);

[X_grid, Y_grid] = meshgrid(X, Y);

I_padded = padarray(I, [1, 1], 0, 'post');

hold_state = ishold(ax);
h = pcolor(ax, X_grid, Y_grid, I_padded);

set(h, 'EdgeColor', 'none', 'FaceColor', 'flat'); 
set(ax, 'YDir', 'reverse');
axis(ax, 'tight');

if length(x) < 50
    set(ax, 'XTick', x);
end
if length(y) < 50
    set(ax, 'YTick', y);
end

if ~hold_state
    hold(ax, 'off');
end

if nargout > 0
    varargout{1} = h;
end

end

function bounds = calculate_bounds(vec)
    if length(vec) > 1
        d = diff(vec);
        bounds = [vec(1)-d(1)/2, vec(1:end-1)+d/2, vec(end)+d(end)/2];
    else
        bounds = [vec - 0.5, vec + 0.5];
    end
end