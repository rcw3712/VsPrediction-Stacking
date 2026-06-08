function logfile = setup_logger(cfg)
% SETUP_LOGGER — create timestamped log + diary in audit dir
%   Author: RCW (2026-06)

if ~exist(cfg.audit_dir, 'dir'), mkdir(cfg.audit_dir); end
stamp = datestr(now, 'yyyymmdd_HHMMSS');
logfile = fullfile(cfg.audit_dir, sprintf('run_%s.log', stamp));
diary(logfile);
diary on;
fprintf('\n[LOGGER] Output mirrored to: %s\n', logfile);
end
