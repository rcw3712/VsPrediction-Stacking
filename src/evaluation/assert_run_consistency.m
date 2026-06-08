function ok = assert_run_consistency(run_dir, M, winner_kind, scenarios)
% ASSERT_RUN_CONSISTENCY — QC gate (manuscript-ready).
%
%   Checks:
%     1. table3_test_performance.csv + final_model_ranking.xlsx exist
%     2. Rank #1 (by R²) consistent across both tables
%     3. ★ Deployed marker matches winner_kind
%     4. All Domain entries == 'physical_kms'
%     5. Feature scenarios truly distinct (using direct scenarios struct,
%        NOT re-read CSV — avoids false-positive from header-mangling)
%     6. Fig4 + Fig6 successfully written (warns if missing)
%
%   ALL readtable calls use 'VariableNamingRule','preserve' so columns
%   like "RMSE (km/s)" are read intact. Column lookup goes through
%   getTableColumn for case/punctuation-insensitive matching.
%
%   Author: RCW (2026-06)

ok = false;
tables_dir   = fullfile(run_dir, 'tables');
pubfigs_dir  = fullfile(run_dir, 'figures_publication');

problems = strings(0, 1);
warns    = strings(0, 1);

% --- 1. table3 + final_ranking exist
t3_path = fullfile(tables_dir, 'table3_test_performance.csv');
fr_path = fullfile(tables_dir, 'final_model_ranking.xlsx');
if ~exist(t3_path, 'file'), problems(end+1) = sprintf('Missing: %s', t3_path); end
if ~exist(fr_path, 'file'), problems(end+1) = sprintf('Missing: %s', fr_path); end

% --- 2-4. Cross-table consistency
if isempty(problems)
    T3 = readtable(t3_path, 'VariableNamingRule', 'preserve');
    FR = readtable(fr_path, 'VariableNamingRule', 'preserve');
    
    t3_kind_col = getTableColumn(T3, {'Kind','Model','kind','model'}, []);
    fr_kind_col = getTableColumn(FR, {'kind','Kind','Model','model'}, []);
    
    if ~isempty(t3_kind_col) && ~isempty(fr_kind_col)
        t3_rank1 = string(t3_kind_col{1});
        fr_rank1 = string(fr_kind_col{1});
        if ~strcmpi(t3_rank1, fr_rank1)
            problems(end+1) = sprintf( ...
                'Rank inconsistency: table3 rank-1=%s, final_ranking rank-1=%s', ...
                t3_rank1, fr_rank1);
        end
    end
    
    % Deployment marker
    fr_note_col = getTableColumn(FR, {'note','Note'}, {});
    if ~isempty(fr_note_col)
        notes_str = string(fr_note_col);
        deploy_idx = find(contains(notes_str, 'DEPLOY', 'IgnoreCase', true), 1);
        if ~isempty(deploy_idx)
            deployed = string(fr_kind_col{deploy_idx});
            if ~strcmpi(deployed, winner_kind)
                problems(end+1) = sprintf( ...
                    'Deployment marker mismatch: file=%s, winner_kind=%s', ...
                    deployed, winner_kind);
            end
        end
    end
    
    % Domain column
    t3_dom = getTableColumn(T3, {'Domain','domain'}, {});
    if ~isempty(t3_dom)
        dom_str = string(t3_dom);
        bad = ~strcmpi(dom_str, 'physical_kms');
        if any(bad)
            problems(end+1) = sprintf( ...
                'table3 contains non-physical Domain entries at rows: %s', ...
                num2str(find(bad)'));
        end
    else
        warns(end+1) = "table3 missing 'Domain' column";
    end
end

% --- 5. Feature scenarios distinctness (use struct directly, not CSV)
if nargin >= 4 && ~isempty(scenarios)
    sets_str = strings(numel(scenarios), 1);
    for s = 1:numel(scenarios)
        f = scenarios(s).features;
        if iscell(f), f = string(f); end
        sets_str(s) = strjoin(sort(f), ',');
    end
    n_distinct = numel(unique(sets_str));
    if n_distinct < 2
        warns(end+1) = sprintf( ...
            'Feature scenarios degenerate: %d/%d distinct sets — ablation not meaningful', ...
            n_distinct, numel(scenarios));
    elseif n_distinct < numel(scenarios)
        warns(end+1) = sprintf( ...
            'Feature scenarios partially overlap: %d/%d distinct sets', ...
            n_distinct, numel(scenarios));
    end
end

% --- 6. Publication figures exist
required_pubs = {'Fig4_model_ranking_pub.png', 'Fig6_NEJ-2_multitrack_pub.png'};
for k = 1:numel(required_pubs)
    p = fullfile(pubfigs_dir, required_pubs{k});
    if ~exist(p, 'file')
        warns(end+1) = sprintf('Missing publication figure: %s', required_pubs{k});
    end
end

% --- Report ---
fprintf('\n========================================================\n');
fprintf('  QC GATE: assert_run_consistency\n');
fprintf('========================================================\n');
if ~isempty(warns)
    fprintf('  Warnings:\n');
    for i = 1:numel(warns), fprintf('    ⚠  %s\n', warns(i)); end
end
if isempty(problems)
    fprintf('  ✓ All HARD checks passed.\n');
    if isempty(warns)
        fprintf('  Run is FULLY ready for manuscript-level audit.\n');
    else
        fprintf('  Run is ready for manuscript-level audit (with warnings — review above).\n');
    end
    fprintf('========================================================\n\n');
    ok = true;
else
    fprintf('  ✗ FAILED checks:\n');
    for i = 1:numel(problems), fprintf('    ✗  %s\n', problems(i)); end
    fprintf('========================================================\n\n');
    error('QC gate failed — see report above');
end
end
