function model = train_hybrid_icnn(X_train_z, Z_oof, y_train_z, cfg)
% TRAIN_HYBRID_ICNN — concatenates original features X with base preds Z
%   for a multi-channel input to a small CNN.
%   X_train_z: n × p features (z-score)
%   Z_oof:     n × M base predictions (z-score)
%   Author: RCW (2026-06)

[n, p] = size(X_train_z);
M      = size(Z_oof, 2);
n_ch   = p + M;   % concatenated channels

try
    Xseq = cell(n, 1);
    for i = 1:n
        v = [X_train_z(i,:), Z_oof(i,:)];
        Xseq{i} = reshape(v, 1, n_ch);
    end
    layers = [
        sequenceInputLayer(1, 'MinLength', n_ch)
        convolution1dLayer(cfg.model.hybrid_icnn.kernels(1), ...
                           cfg.model.hybrid_icnn.filters, 'Padding', 'same')
        batchNormalizationLayer
        reluLayer
        dropoutLayer(0.2)
        convolution1dLayer(cfg.model.hybrid_icnn.kernels(min(2,end)), ...
                           cfg.model.hybrid_icnn.filters, 'Padding', 'same')
        reluLayer
        globalAveragePooling1dLayer
        fullyConnectedLayer(32)
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer
    ];
    opts = trainingOptions('adam', ...
        'InitialLearnRate', cfg.model.hybrid_icnn.lr, ...
        'MaxEpochs',        cfg.model.hybrid_icnn.epochs, ...
        'MiniBatchSize',    32, ...
        'Verbose',          false, ...
        'Plots',            'none');
    net = trainNetwork(Xseq, y_train_z, layers, opts);
    model.kind = 'hybrid_icnn';
    model.net  = net;
    model.n_ch = n_ch;
catch ME
    warning('Hybrid I-CNN training failed (%s) — falling back to ridge.', ME.message);
    model = train_ridge_stacker(Z_oof, y_train_z, cfg);
    model.kind = 'hybrid_fallback_ridge';
end
end
