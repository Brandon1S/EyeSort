function EEG = parse_and_bin_events(EEG, bdf_file, varargin)


% PURPOSE: Custom BINLISTER-like function to parse BDF and assign events to bins
%
% INPUTS:
% EEG           - EEG structure containing EVENTLIST
% bdf_file      - Path to the Bin Descriptor File (BDF)
%
% OPTIONAL PARAMETERS (varargin):
% 'Ignore'      - Event codes to ignore (numeric array)
% 'Forbidden'   - Event codes that prevent a bin assignment (numeric array)
% 'ExportEL'    - File path to export updated EVENTLIST
% 'Report'      - Flag to generate a performance report ('on'/'off')
%
% OUTPUTS:
% EEG           - EEG structure with updated EVENTLIST
%
% EXAMPLE:
% EEG = parse_and_bin_events(EEG, 'bdf_example.txt', 'Ignore', [99, 100], ...
%       'ExportEL', 'eventlist_updated.txt', 'Report', 'on');
%
% 
% 

% Parse input arguments
p = inputParser;
addRequired(p, 'EEG');
addRequired(p, 'bdf_file', @ischar);
addParameter(p, 'Ignore', [], @isnumeric);
addParameter(p, 'Forbidden', [], @isnumeric);
addParameter(p, 'ExportEL', '', @ischar);
addParameter(p, 'Report', 'off', @(x) any(strcmpi(x, {'on', 'off'})));
parse(p, EEG, bdf_file, varargin{:});

ignore_codes = p.Results.Ignore;
forbidden_codes = p.Results.Forbidden;
export_path = p.Results.ExportEL;
report_flag = p.Results.Report;

% Step 1: Parse the Bin Descriptor File
bins = parse_bdf(bdf_file);

fprintf('BDF parsed successfully. %d bins loaded.\n', length(bins));

% Step 2: Initialize and Validate EVENTLIST
if ~isfield(EEG, 'EVENTLIST') || ~isfield(EEG.EVENTLIST, 'eventinfo')

    error('EEG.EVENTLIST not found. Use "Create EVENTLIST" first.');

end

% Step 3: Event Matching and Bin Assignment
eventinfo = EEG.EVENTLIST.eventinfo;

for i = 1:length(eventinfo)

    % Skip ignored events
    if ismember(eventinfo(i).code, ignore_codes)

        continue;

    end
    
    % Check for forbidden events
    for b = 1:length(bins)

        if ismember(eventinfo(i).code, bins(b).forbidden_codes)

            continue;

        end
        
        % Match events to bins
        if ismember(eventinfo(i).code, bins(b).event_codes)

            % Temporal constraints logic (to be added)

            eventinfo(i).bini = bins(b).bin_number;
        end
    end
end

% Step 4: Update EEG.EVENTLIST
EEG.EVENTLIST.eventinfo = eventinfo;
fprintf('Event assignment to bins completed.\n');

% Step 5: Export Updated EVENTLIST (Optional)
if ~isempty(export_path)

    export_eventlist(eventinfo, export_path);

    fprintf('Updated EVENTLIST saved to: %s\n', export_path);

end

% Step 6: Generate Report (Optional)
if strcmpi(report_flag, 'on')

    generate_report(eventinfo, bins);

end

end

