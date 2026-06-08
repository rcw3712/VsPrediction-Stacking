function model = train_icnn_stacker(Z_oof, y_train_z, cfg)
% TRAIN_ICNN_STACKER — I-CNN treating M base preds as M-channel sequence.
%   Falls back to ridge if Deep Learning Toolbox not available.
%   Author: RCW (2026-06)

[n, M] = size(Z_oof);

try
    Xseq = cell(n, 1);
    for i = 1:n
        Xseq{i} = reshape(Z_oof(i,:), 1, M);
    end
    layers = [
        sequenceInputLayer(1, 'MinLength', M)
        convolution1dLayer(cfg.model.icnn.kernels(1), cfg.model.icnn.filters, ...
                           'Padding', 'same')
        batchNormalizationLayer
        reluLayer
        dropoutLayer(cfg.model.icnn.dropout)
        convolution1dLayer(cfg.model.icnn.kernels(min(2,end)), ...
                           cfg.model.icnn.filters, 'Padding', 'same')
        reluLayer
        globalAveragePooling1dLayer
        fullyConnectedLayer(16)
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer
    ];
    opts = trainingOptions('adam', ...
        'InitialLearnRate', cfg.model.icnn.lr, ...
        'MaxEpochs',        cfg.model.icnn.epochs, ...
        'MiniBatchSize',    32, ...
        'Verbose',          false, ...
        'Plots',            'none');
    net = trainNetwork(Xseq, y_train_z, layers, opts);
    model.kind = 'icnn';
    model.net  = net;
    model.M    = M;
catch ME
    warning('I-CNN stacker training failed (%s) — falling back to ridge.', ME.message);
    model = train_ridge_stacker(Z_oof, y_train_z, cfg);
    model.kind = 'icnn_fallback_ridge';
end
end
