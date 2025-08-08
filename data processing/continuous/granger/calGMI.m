function I = calGMI(X, W)
    % vectorize X
    X = X(:);

    % exclude nan values
    nanIdx = find(isnan(X));
    
    % number of none-nan indices
    N = numel(X) - numel(nanIdx);

    % subtract mean
    X = X - nanmean(X);

    % set X and W for nan values to 0
    X(nanIdx) = 0;
    W(nanIdx, :) = 0;
    W(:, nanIdx) = 0;

    % if all X values are the same
    if ~all(X)
        I = 0;
        return;
    end

    I = (N / sum(W, "all")) * (sum(W * X .* X) / sum(X .^ 2));
    return;
end