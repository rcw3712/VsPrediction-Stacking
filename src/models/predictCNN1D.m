function yhat = predictCNN1D(mdl, X, params)
%PREDICTCNN1D  Inference for the windowed 1-D CNN.

if nargin < 3, params = mdl.params; end
W  = params.windowSize;
[Xw, ~] = makeWindows(X, zeros(size(X,1),1), W);
N = numel(Xw);
P = size(X,2);
Xa = zeros(W, P, 1, N, 'single');
for i = 1:N; Xa(:,:,1,i) = single(Xw{i}); end
yhat = predict(mdl.net, Xa);
yhat = double(yhat(:));
end
