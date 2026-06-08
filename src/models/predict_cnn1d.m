function y_hat = predict_cnn1d(model, X)
% PREDICT_CNN1D — returns DOUBLE precision predictions.
%   Author: RCW (2026-06)

if strcmp(model.kind, 'cnn1d_fallback')
    y_hat = predict_mlffnn(model, X);
    y_hat = double(y_hat);
    return;
end

[n, p] = size(X);
Xseq = cell(n, 1);
for i = 1:n
    Xseq{i} = reshape(X(i,:), 1, p);
end
y_hat = predict(model.net, Xseq);
y_hat = double(y_hat);   % trainNetwork outputs single; cast to double
end
