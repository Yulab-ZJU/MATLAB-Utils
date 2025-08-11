function rgb = genGradientColors(n, c, smin)
% Generate gradient colors from specified [c] to white.
% Inputs:
%   n: number of colors
%   c: initial color
%   smin: the minimum saturation (at the white end). Default is 0 (for white).
%
% Output:
%   rgb: [n x 1] cell

narginchk(1, 3);

if nargin < 2
    c = 'r';
end

if nargin < 3
    smin = 0; % min saturation, [0, 1]
end

hsv = rgb2hsv(validatecolor(c));

s0 = hsv(2);
v0 = hsv(3);
hsv = repmat(hsv, [n, 1]);
hsv(:, 2) = linspace(s0, smin, n);
hsv(:, 3) = linspace(v0, 1, n);

rgb = hsv2rgb(hsv);
rgb = num2cell(rgb, 2);
return;
end