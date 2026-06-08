function m = force_metric_fields(m_in)
% FORCE_METRIC_FIELDS — return a metric struct with EXACTLY these 7 fields
%   in EXACTLY this order, with all numeric values cast to DOUBLE.
%
%   Fields: R2, RMSE_kms, MAE_kms, MAPE_percent, Bias_kms, N, Domain
%
%   This is the single canonical schema used by:
%     - evaluate_model
%     - build_model_results_master
%     - select_deployment_model
%     - assert_run_consistency
%
%   Use this whenever you build a metric struct that will be assigned into
%   a struct array, to prevent the "Subscripted assignment between
%   dissimilar structures" error.
%
%   Author: RCW (2026-06)

% Canonical schema
m = struct( ...
    'R2',           NaN, ...
    'RMSE_kms',     NaN, ...
    'MAE_kms',      NaN, ...
    'MAPE_percent', NaN, ...
    'Bias_kms',     NaN, ...
    'N',            0,   ...
    'Domain',       'physical_kms');

if nargin == 0 || isempty(m_in), return; end

% Copy across whichever fields the input has (with legacy aliases)
field_map = { ...
    'R2',           {'R2','r2'}; ...
    'RMSE_kms',     {'RMSE_kms','RMSE','rmse','rmse_kms'}; ...
    'MAE_kms',      {'MAE_kms','MAE','mae','mae_kms'}; ...
    'MAPE_percent', {'MAPE_percent','MAPE','mape','mape_percent'}; ...
    'Bias_kms',     {'Bias_kms','bias','Bias','bias_kms'}; ...
    'N',            {'N','n','n_samples'}; ...
    'Domain',       {'Domain','domain'}};

for k = 1:size(field_map, 1)
    canonical = field_map{k, 1};
    aliases   = field_map{k, 2};
    for a = 1:numel(aliases)
        if isfield(m_in, aliases{a})
            v = m_in.(aliases{a});
            if isnumeric(v), v = double(v); end
            m.(canonical) = v;
            break;
        end
    end
end
end
