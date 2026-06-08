function T = read_well_excel_canonical(xlsx_path, cfg, well_name)
% READ_WELL_EXCEL_CANONICAL
%   Robust Excel reader that returns a table with CANONICAL column names:
%     DEPTH (m), GR (API), RHOB (g/cm³), NPHI (v/v), PHIE (fraction),
%     VP (km/s), VS (km/s, if present).
%
%   Handles:
%     - Sheet auto-selection (first sheet by default)
%     - Column-name variants and unit suffixes "(FT)", "(M/S)", "(API)"
%     - Thousand-separator commas in numeric values
%     - UTF-8 BOM in headers
%     - Null sentinels (-999, -999.25, -9999, -99999)
%     - Unit conversion: depth FT→M, Vp/Vs M/S→KM/S
%
%   Sanity-checks values against cfg.data.sanity to catch swapped columns.
%
%   Author: RCW (2026-06)

if ~exist(xlsx_path, 'file')
    error('Excel file not found: %s', xlsx_path);
end

% -------------------------------------------------------------------------
% Read first sheet
% -------------------------------------------------------------------------
try
    sheets = sheetnames(xlsx_path);
catch
    [~, sheets] = xlsfinfo(xlsx_path);
end
if isempty(sheets)
    error('No sheets found in %s', xlsx_path);
end
sheet = sheets{1};

opts = detectImportOptions(xlsx_path, 'Sheet', sheet, ...
                           'PreserveVariableNames', true);
T_raw = readtable(xlsx_path, opts);
raw_cols = T_raw.Properties.VariableNames;

% Strip UTF-8 BOM from first column name
v1 = raw_cols{1};
bom_chars = [char(65279), char(239), char(187), char(191)];
for c = bom_chars
    v1 = strrep(v1, c, '');
end
T_raw.Properties.VariableNames{1} = strtrim(v1);
raw_cols = T_raw.Properties.VariableNames;

% -------------------------------------------------------------------------
% Build canonical table — populate by NAME, never by index
% -------------------------------------------------------------------------
T = table();
T_full_log = cell(0, 3);   % {raw_name, canonical, unit_detected}

for k = 1:numel(raw_cols)
    raw_name = raw_cols{k};
    
    % Extract unit suffix if present
    m = regexp(raw_name, '\(([^)]+)\)', 'tokens', 'once');
    unit = '';
    if ~isempty(m), unit = strtrim(upper(m{1})); end
    
    % Strip suffix to get bare name
    bare = regexprep(raw_name, '\s*\([^)]*\)\s*', '');
    bare = strtrim(bare);
    
    % Map to canonical
    canonical = map_to_canonical(bare);
    if isempty(canonical)
        continue;   % unrecognized column → skip silently
    end
    
    % Coerce column to numeric (handle thousand-separator commas)
    col_data = T_raw{:, k};
    col_data = coerce_numeric(col_data);
    
    % Replace null sentinels with NaN
    for s = cfg.data.null_sentinels(:)'
        col_data(col_data == s) = NaN;
    end
    
    % Unit conversion
    [col_data, unit_final] = apply_unit_conversion(col_data, canonical, unit);
    
    % Assign (skip if duplicate canonical — keep first)
    if ~ismember(canonical, T.Properties.VariableNames)
        T.(canonical) = col_data;
        T_full_log(end+1, :) = {raw_name, canonical, unit_final};
    end
end

% -------------------------------------------------------------------------
% Required columns
% -------------------------------------------------------------------------
required = {'DEPTH','GR','RHOB','NPHI','VP'};
for k = 1:numel(required)
    if ~ismember(required{k}, T.Properties.VariableNames)
        error('[%s] missing required canonical column: %s. Detected raw columns: %s', ...
              well_name, required{k}, strjoin(raw_cols, ', '));
    end
end

% PHIE is recommended but not strictly required
if ~ismember('PHIE', T.Properties.VariableNames)
    warning('[%s] PHIE column not found — pipeline will compute from NPHI', well_name);
end

% VS only required for training well
if strcmp(well_name, 'NEJ-1') && ~ismember('VS', T.Properties.VariableNames)
    error('[%s] training well requires VS column', well_name);
end

% -------------------------------------------------------------------------
% Sort by depth, drop rows with NaN depth
% -------------------------------------------------------------------------
T(isnan(T.DEPTH), :) = [];
T = sortrows(T, 'DEPTH');

% -------------------------------------------------------------------------
% Sanity checks against expected ranges (catches swapped columns)
% -------------------------------------------------------------------------
sanity_check_columns(T, cfg.data.sanity, well_name);

% -------------------------------------------------------------------------
% Log column mapping
% -------------------------------------------------------------------------
fprintf('  [IO] %s column map:\n', well_name);
for k = 1:size(T_full_log, 1)
    fprintf('       ''%s'' → %s  (unit: %s)\n', ...
            T_full_log{k,1}, T_full_log{k,2}, T_full_log{k,3});
end

end


% =========================================================================
% Map raw column name to canonical
% =========================================================================
function canonical = map_to_canonical(bare)
b = lower(strtrim(bare));
mapping = {
    {'depth','dept','md','tvd','depth_m','depth_ft'},     'DEPTH';
    {'gr','gamma','gammaray','gamma_ray','grapi'},        'GR';
    {'rhob','density','rho_b','dens','dens_b','rho'},     'RHOB';
    {'nphi','neutron','nphi_lim','tnph'},                 'NPHI';
    {'phie','porosity','phi_e','phit','phi'},             'PHIE';
    {'vp','vp_log','dtc','dt_c','vp_ms','p_velocity'},    'VP';
    {'vs','vs_log','dts','dt_s','vs_ms','s_velocity'},    'VS';
};
for k = 1:size(mapping,1)
    if any(strcmp(b, mapping{k,1}))
        canonical = mapping{k,2};
        return;
    end
end
canonical = '';
end


% =========================================================================
% Coerce column to numeric, handling text variants
% =========================================================================
function col_num = coerce_numeric(col_data)
if isnumeric(col_data)
    col_num = double(col_data);
elseif iscell(col_data)
    s = string(col_data);
    s = strrep(s, ',', '');   % strip US-format thousand separator
    s = strrep(s, ' ', '');
    col_num = str2double(s);
elseif isstring(col_data)
    s = strrep(col_data, ',', '');
    s = strrep(s, ' ', '');
    col_num = str2double(s);
else
    try
        col_num = double(col_data);
    catch
        col_num = nan(size(col_data));
    end
end
end


% =========================================================================
% Apply unit conversion: DEPTH FT→M, VP/VS M/S→KM/S
% =========================================================================
function [data, unit_final] = apply_unit_conversion(data, canonical, unit_raw)
unit_final = unit_raw;
if isempty(unit_final), unit_final = '(none)'; end

switch upper(canonical)
    case 'DEPTH'
        if any(strcmpi(unit_raw, {'FT','FEET','FOOT'}))
            data = data * 0.3048;
            unit_final = 'FT→M';
        elseif any(strcmpi(unit_raw, {'M','METER','METERS'})) || isempty(unit_raw)
            unit_final = 'M';
        end
        
    case {'VP','VS'}
        % Detect m/s vs km/s by VALUE RANGE (more reliable than unit suffix)
        valid = data(~isnan(data) & data > 0);
        if ~isempty(valid)
            med = median(valid);
            if med > 100   % almost certainly m/s
                data = data / 1000;
                unit_final = sprintf('%s→km/s (auto)', unit_raw);
            elseif contains(upper(unit_raw), 'KM')
                unit_final = 'km/s';
            else
                unit_final = 'km/s (assumed)';
            end
        end
        
    case 'PHIE'
        % Detect fraction (0-1) vs percent (0-100)
        valid = data(~isnan(data) & data >= 0);
        if ~isempty(valid)
            med = median(valid);
            if med > 1.5   % almost certainly percent
                data = data / 100;
                unit_final = sprintf('%s→fraction (auto / was %%)', unit_raw);
            else
                unit_final = 'fraction';
            end
        end
end
end


% =========================================================================
% Sanity-check column values against expected ranges
% =========================================================================
function sanity_check_columns(T, sanity, well_name)
problems = {};
for fname = fieldnames(sanity)'
    f = fname{1};
    if ~ismember(f, T.Properties.VariableNames), continue; end
    vals = T.(f);
    vals = vals(~isnan(vals));
    if isempty(vals)
        problems{end+1} = sprintf('  - %s: all NaN', f);
        continue;
    end
    med = median(vals);
    rng = sanity.(f);
    if med < rng(1) || med > rng(2)
        problems{end+1} = sprintf( ...
            '  - %s: median=%.3f outside expected range [%.2f, %.2f] — possible swap!', ...
            f, med, rng(1), rng(2));
    end
end
if ~isempty(problems)
    warning('[%s] sanity-check WARNINGS:\n%s', well_name, ...
            strjoin(problems, newline));
end
end
