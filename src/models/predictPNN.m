function yhat = predictPNN(mdl, X)
%PREDICTPNN  Predict with a GRNN/PNN model.

switch mdl.kind
    case 'newgrnn'
        yhat = sim(mdl.net, X.');
        yhat = yhat(:);
    case 'manual'
        N  = size(X,1);
        yhat = zeros(N,1);
        s2 = 2 * mdl.spread^2;
        for i = 1:N
            d2 = sum((mdl.X - X(i,:)).^2, 2);
            w  = exp(-d2 / s2);
            sw = sum(w);
            if sw == 0
                yhat(i) = mean(mdl.y);
            else
                yhat(i) = sum(w .* mdl.y) / sw;
            end
        end
end
end
