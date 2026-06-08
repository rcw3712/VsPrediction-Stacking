function safe_mkdir(p)
% SAFE_MKDIR — create directory if missing
if ~exist(p, 'dir'), mkdir(p); end
end
