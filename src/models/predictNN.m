function yhat = predictNN(mdl, X)
%PREDICTNN  Inference for a feature-input dlnetwork.

yhat = predict(mdl.net, X);
yhat = double(yhat(:));
end
