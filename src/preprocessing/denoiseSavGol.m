function y = denoiseSavGol(x, polyOrder, frameLen)
%DENOISESAVGOL  Apply a Savitzky-Golay smoothing filter to a 1-D log.
%
%   polyOrder : polynomial order (default 3)
%   frameLen  : window length, must be odd and > polyOrder (default 11)

if nargin < 2, polyOrder = 3;  end
if nargin < 3, frameLen  = 11; end
frameLen = max(polyOrder + 2, frameLen);
if mod(frameLen,2) == 0, frameLen = frameLen + 1; end

x = x(:);
if numel(x) < frameLen
    y = x; return;
end

try
    y = sgolayfilt(x, polyOrder, frameLen);
catch
    % Fallback: simple moving average
    y = movmean(x, frameLen, 'omitnan');
end
end
