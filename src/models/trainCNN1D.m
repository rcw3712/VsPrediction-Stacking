function mdl = trainCNN1D(X, y, params)
%TRAINCNN1D  1-D Convolutional Neural Network on depth-windows.
%
%   Each sample i is converted to a window [W x P] containing the W
%   contiguous depth samples ending at i. This lets the CNN exploit
%   vertical context (the most informative direction for well logs).

if nargin < 3, params = struct(); end
defaults = struct('numFilters',32,'kernelSize',5,'numBlocks',3, ...
                  'maxEpochs',200,'lr',5e-4,'dropout',0.2,'windowSize',16);
params = mergeStruct(defaults, params);

[Xw, yw] = makeWindows(X, y, params.windowSize);
% Xw: cell of [W x P] inputs -> we stack as [W x P x 1 x N]
N = numel(Xw);
W = params.windowSize;
P = size(X,2);
Xa = zeros(W, P, 1, N, 'single');
for i = 1:N; Xa(:,:,1,i) = single(Xw{i}); end
ya = single(yw);

layers = [imageInputLayer([W P 1], 'Normalization','none','Name','input')];
for b = 1:params.numBlocks
    nf = params.numFilters * 2^(b-1);
    layers = [layers
        convolution2dLayer([min(params.kernelSize,W) 1], nf, 'Padding','same', ...
            'Name', sprintf('conv%d',b))
        batchNormalizationLayer('Name', sprintf('bn%d',b))
        reluLayer('Name', sprintf('relu%d',b))
        maxPooling2dLayer([2 1],'Stride',[2 1],'Padding','same', ...
            'Name',sprintf('pool%d',b))
        dropoutLayer(params.dropout,'Name',sprintf('do%d',b))]; %#ok<AGROW>
end
layers = [layers
    globalAveragePooling2dLayer('Name','gap')
    fullyConnectedLayer(64,'Name','fc1')
    reluLayer('Name','fcrelu')
    dropoutLayer(params.dropout,'Name','fcdo')
    fullyConnectedLayer(1,'Name','out')];

patience = 25; if isfield(params,'patience'), patience = params.patience; end

opts = trainingOptions('adam', ...
    'MaxEpochs',         params.maxEpochs, ...
    'InitialLearnRate',  params.lr, ...
    'MiniBatchSize',     min(32, N), ...
    'Shuffle',           'every-epoch', ...
    'Verbose',            false, ...
    'OutputNetwork',      'best-validation-loss', ...
    'ValidationFrequency',10, ...
    'ValidationPatience', patience);

rng(7, 'twister');         % fixed seed for CNN1D reproducibility
nv = max(1, round(0.15*N));
idx = randperm(N); val = idx(1:nv); tra = idx(nv+1:end);
opts.ValidationData = {Xa(:,:,:,val), ya(val)};

[net, info] = trainnet(Xa(:,:,:,tra), ya(tra), layers, 'mse', opts);
mdl.net    = net;
mdl.kind   = 'cnn1d';
mdl.params = params;
mdl.trainInfo = info;
end

function s = mergeStruct(a, b)
s = a;
fn = fieldnames(b);
for k = 1:numel(fn); s.(fn{k}) = b.(fn{k}); end
end
