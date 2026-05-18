function [Xw, yw] = makeWindows(X, y, W)
%MAKEWINDOWS  Build depth-windows of length W ending at each sample.
%   Output:
%     Xw : cell{N} of [W x P]
%     yw : Nx1 corresponding targets

N = size(X,1);
Xw = cell(N,1);
yw = zeros(N,1);
for i = 1:N
    s = max(1, i - W + 1);
    win = X(s:i, :);
    if size(win,1) < W
        % left-pad with the first available row
        pad = repmat(win(1,:), W - size(win,1), 1);
        win = [pad; win];
    end
    Xw{i} = win;
    yw(i) = y(i);
end
end
