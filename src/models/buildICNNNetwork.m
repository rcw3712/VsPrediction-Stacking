function lgraph = buildICNNNetwork(W, P, params)
%BUILDICNNNETWORK  Build a multi-stack 1-D CNN with multi-scale kernels.
%
%   Architecture
%       Input [W x P x 1]
%         |--> Stack-A (kernel small)  ---\
%         |--> Stack-B (kernel medium)  --> Fusion --> FC --> Vs
%         |--> Stack-C (kernel large)  ---/
%
%   params.kernelsMulti     : e.g. [3 5 7]
%   params.numStacks        : depth of each stack
%   params.filtersPerStack  : base filter count
%   params.fusion           : 'concat' | 'sum' | 'attention'
%   params.fcSizes          : FC head sizes
%   params.dropout

K = numel(params.kernelsMulti);
lgraph = layerGraph();
lgraph = addLayers(lgraph, ...
    imageInputLayer([W P 1], 'Normalization','none','Name','input'));

stackOuts = cell(1, K);
for s = 1:K
    ks = min(params.kernelsMulti(s), W);
    pname = sprintf('s%d_', s);
    L = [];
    for b = 1:params.numStacks
        nf = params.filtersPerStack * 2^(b-1);
        L = [L
            convolution2dLayer([ks 1], nf, 'Padding','same', ...
                'Name', [pname sprintf('conv%d',b)])
            batchNormalizationLayer('Name', [pname sprintf('bn%d',b)])
            reluLayer('Name', [pname sprintf('relu%d',b)])
            maxPooling2dLayer([2 1],'Stride',[2 1],'Padding','same', ...
                'Name', [pname sprintf('pool%d',b)])
            dropoutLayer(params.dropout, 'Name', [pname sprintf('do%d',b)])]; %#ok<AGROW>
    end
    L = [L
        globalAveragePooling2dLayer('Name', [pname 'gap'])];
    lgraph = addLayers(lgraph, L);
    lgraph = connectLayers(lgraph, 'input', [pname 'conv1']);
    stackOuts{s} = [pname 'gap'];
end

% --- Fusion -------------------------------------------------------------
switch lower(params.fusion)
    case 'concat'
        fusion = concatenationLayer(3, K, 'Name','fuse');
    case 'sum'
        fusion = additionLayer(K, 'Name','fuse');
    case 'attention'
        % Soft-attention over stacks: compute a weight vector via FC on
        % concatenated features and apply softmax-weighted sum.
        % For simplicity we fall back to a learnable concatenation.
        fusion = concatenationLayer(3, K, 'Name','fuse');
    otherwise
        fusion = concatenationLayer(3, K, 'Name','fuse');
end
lgraph = addLayers(lgraph, fusion);
for s = 1:K
    lgraph = connectLayers(lgraph, stackOuts{s}, sprintf('fuse/in%d', s));
end

% --- FC head -----------------------------------------------------------
H = [];
for k = 1:numel(params.fcSizes)
    H = [H
        fullyConnectedLayer(params.fcSizes(k), 'Name', sprintf('fc%d',k))
        reluLayer('Name', sprintf('fcrelu%d',k))
        dropoutLayer(params.dropout, 'Name', sprintf('fcdo%d',k))]; %#ok<AGROW>
end
H = [H
    fullyConnectedLayer(1, 'Name','out')];
lgraph = addLayers(lgraph, H);
lgraph = connectLayers(lgraph, 'fuse', 'fc1');
end
