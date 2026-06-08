function audit_loaded_data(D1, D2, cfg)
% AUDIT_LOADED_DATA — print and save a comprehensive audit of both wells.
%   D1 : NEJ-1 training well table (must have VS)
%   D2 : NEJ-2 blind well table (no VS)
%
%   Writes to cfg.audit_dir/data_audit.txt
%
%   Author: RCW (2026-06)

if ~exist(cfg.audit_dir, 'dir'), mkdir(cfg.audit_dir); end
audit_path = fullfile(cfg.audit_dir, 'data_audit.txt');
fid_audit  = fopen(audit_path, 'w');
if fid_audit < 0
    warning('Could not open audit file for writing: %s', audit_path);
    fid_audit = 1;   % fall back to stdout
end

% Print to both stdout (fid=1) and the file
function print(varargin)
    fprintf(1, varargin{:});
    if fid_audit > 1, fprintf(fid_audit, varargin{:}); end
end

print('\n========================================================================\n');
print('  DATA AUDIT — NEJ-1 (training) and NEJ-2 (blind)\n');
print('  Timestamp: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
print('========================================================================\n\n');

audit_one_well(D1, cfg.data.train_well, cfg, @print);
print('\n------------------------------------------------------------------------\n\n');
audit_one_well(D2, cfg.data.blind_well, cfg, @print);

print('\n========================================================================\n');
print('  CROSS-WELL COMPARISON\n');
print('========================================================================\n');
common = intersect(D1.Properties.VariableNames, D2.Properties.VariableNames);
print('  Common columns: %s\n', strjoin(common, ', '));
print('  Training-only columns: %s\n', ...
      strjoin(setdiff(D1.Properties.VariableNames, common), ', '));
print('  Blind-only columns:    %s\n', ...
      strjoin(setdiff(D2.Properties.VariableNames, common), ', '));

print('\n  Depth coverage:\n');
print('    %s: [%.2f, %.2f] m   (span %.2f m)\n', ...
      cfg.data.train_well, min(D1.DEPTH), max(D1.DEPTH), ...
      max(D1.DEPTH) - min(D1.DEPTH));
print('    %s: [%.2f, %.2f] m   (span %.2f m)\n', ...
      cfg.data.blind_well, min(D2.DEPTH), max(D2.DEPTH), ...
      max(D2.DEPTH) - min(D2.DEPTH));

% Compute depth overlap
overlap_lo = max(min(D1.DEPTH), min(D2.DEPTH));
overlap_hi = min(max(D1.DEPTH), max(D2.DEPTH));
if overlap_hi > overlap_lo
    print('    Depth overlap: [%.2f, %.2f] m\n', overlap_lo, overlap_hi);
else
    print('    *** NO DEPTH OVERLAP *** — vertical extrapolation regime\n');
end

print('\n  VS availability:\n');
print('    %s: VS PRESENT (target)\n', cfg.data.train_well);
if ismember('VS', D2.Properties.VariableNames)
    n_vs = sum(~isnan(D2.VS));
    print('    %s: VS PRESENT but n_valid=%d (treated as illustrative only)\n', ...
          cfg.data.blind_well, n_vs);
else
    print('    %s: VS ABSENT (blind deployment)\n', cfg.data.blind_well);
end

print('\n========================================================================\n');
print('  Audit complete. Saved: %s\n', audit_path);
print('========================================================================\n\n');

if fid_audit > 1, fclose(fid_audit); end
end


function audit_one_well(D, name, cfg, printfn)
printfn('  WELL: %s\n', name);
printfn('  Total rows: %d\n', height(D));
printfn('  Columns:    %s\n', strjoin(D.Properties.VariableNames, ', '));
printfn('\n  Per-column statistics:\n');
printfn('    %-8s  %8s  %8s  %8s  %8s  %8s  %8s  %s\n', ...
        'Column', 'N_valid', 'N_NaN', 'Min', 'Median', 'Max', 'Std', 'Sanity');

for fname = D.Properties.VariableNames
    f = fname{1};
    v = D.(f);
    n_valid = sum(~isnan(v));
    n_nan   = sum(isnan(v));
    vv = v(~isnan(v));
    if isempty(vv)
        printfn('    %-8s  %8d  %8d  %8s  %8s  %8s  %8s  %s\n', ...
                f, n_valid, n_nan, '—','—','—','—','no data');
        continue;
    end
    sanity_status = '✓';
    if isfield(cfg.data.sanity, f)
        rng = cfg.data.sanity.(f);
        med = median(vv);
        if med < rng(1) || med > rng(2)
            sanity_status = sprintf('⚠ outside [%.2f, %.2f]', rng(1), rng(2));
        end
    end
    printfn('    %-8s  %8d  %8d  %8.3f  %8.3f  %8.3f  %8.3f  %s\n', ...
            f, n_valid, n_nan, min(vv), median(vv), max(vv), std(vv), ...
            sanity_status);
end
end
