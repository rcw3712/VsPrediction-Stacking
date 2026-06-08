function model = train_cnn1d(X_train, y_train, hyperparams)
% TRAIN_CNN1D — 1D convolutional NN using sequenceInputLayer + Conv1D.
%   Falls back to MLP if Deep Learning Toolbox unavailable OR if input
%   feature count is too small for the requested kernel size.
%   X_train: n × p features (treated as p-channel single-step sequences)
%   Author: RCW (2026-06)

if nargin < 3 || isempty(hyperparams)
    hyperparams.kernel  = 3;
    hyperparams.filters = 16;
    hyperparams.epochs  = 50;
    hyperparams.lr      = 0.001;
    hyperparams.dropout = 0.2;
end

[n, p] = size(X_train);

% --- Guard 1: skip CNN1D when feature count is too small for kernel
if p < max(3, hyperparams.kernel)
    fprintf('     [CNN1D] p=%d < kernel=%d → falling back to shallow NN\n', ...
            p, hyperparams.kernel);
    model = train_mlffnn(X_train, y_train);
    model.kind = 'cnn1d_fallback';
    model.hyperparams = hyperparams;
    return;
end

try
    % Build small 1D CNN: each row treated as length-p sequence
    layers = [
        sequenceInputLayer(1, 'MinLength', p)
        convolution1dLayer(hyperparams.kernel, hyperparams.filters, ...
                           'Padding', 'same')
        batchNormalizationLayer
        reluLayer
        dropoutLayer(hyperparams.dropout)
        globalAveragePooling1dLayer
        fullyConnectedLayer(16)
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer
    ];

    % Use validation split for early stopping when n is large enough
    if n >= 200
        rng(42);
        val_n = max(20, round(0.15 * n));
        idx = randperm(n);
        val_idx = idx(1:val_n);
        tr_idx  = idx(val_n+1:end);
        Xtr = X_train(tr_idx, :);  ytr = y_train(tr_idx);
        Xv  = X_train(val_idx, :); yv  = y_train(val_idx);
        Xtr_seq = cell(numel(tr_idx), 1);
        Xv_seq  = cell(numel(val_idx), 1);
        for i = 1:numel(tr_idx),  Xtr_seq{i} = reshape(Xtr(i,:), 1, p); end
        for i = 1:numel(val_idx), Xv_seq{i}  = reshape(Xv(i,:), 1, p);  end
        opts = trainingOptions('adam', ...
            'InitialLearnRate', hyperparams.lr, ...
            'MaxEpochs', hyperparams.epochs, ...
            'MiniBatchSize', 32, ...
            'Shuffle', 'every-epoch', ...
            'ValidationData', {Xv_seq, yv}, ...
            'ValidationFrequency', max(10, floor(numel(tr_idx)/32)), ...
            'ValidationPatience', 5, ...     % early stopping
            'Verbose', false, ...
            'Plots', 'none');
        net = trainNetwork(Xtr_seq, ytr, layers, opts);
    else
        Xseq = cell(n, 1);
        for i = 1:n, Xseq{i} = reshape(X_train(i,:), 1, p); end
        opts = trainingOptions('adam', ...
            'InitialLearnRate', hyperparams.lr, ...
            'MaxEpochs', hyperparams.epochs, ...
            'MiniBatchSize', 32, ...
            'Shuffle', 'every-epoch', ...
            'Verbose', false, ...
            'Plots', 'none');
        net = trainNetwork(Xseq, y_train, layers, opts);
    end
    model.net  = net;
    model.kind = 'cnn1d';
catch ME
    warning('CNN1D training failed (%s). Falling back to shallow NN.', ME.message);
    model = train_mlffnn(X_train, y_train);
    model.kind = 'cnn1d_fallback';
end

model.hyperparams = hyperparams;
end
