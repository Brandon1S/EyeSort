function generate_bdf_file(varargin)
% GENERATE_BDF_FILE - Creates a BINLISTER Bin Descriptor File from EyeSort filtered datasets
%
% Usage:
%   >> generate_bdf_file;                     % Interactive mode with dialog
%   >> generate_bdf_file(EEG);                % Generate BDF from single EEG dataset
%   >> generate_bdf_file(ALLEEG);             % Generate BDF from ALLEEG structure
%   >> generate_bdf_file(EEG, outputFile);    % Specify output file path
%
% Inputs:
%   EEG        - EEGLAB EEG structure with filtered events (optional)
%   ALLEEG     - EEGLAB ALLEEG structure containing filtered datasets (optional)
%   outputFile - Full path to output BDF file (optional)
%
% This function analyzes the 6-digit filter codes in filtered datasets and
% automatically generates a BINLISTER compatible bin descriptor file (BDF).
% The 6-digit codes follow this pattern:
%   - First 2 digits: Condition code (00-99)
%   - Middle 2 digits: Region code (01-99)
%   - Last 2 digits: Filter code (01-99)
%
% See also: pop_filter_datasets, batch_filter_dataset

    % Check for input arguments
    if nargin < 1
        % No inputs provided, retrieve from base workspace
        try
            EEG = evalin('base', 'EEG');
            fprintf('Retrieved EEG from base workspace\n');
        catch
            try
                ALLEEG = evalin('base', 'ALLEEG');
                fprintf('Retrieved ALLEEG from base workspace\n');
                if ~isempty(ALLEEG)
                    EEG = ALLEEG;
                else
                    error('Both EEG and ALLEEG are empty in base workspace');
                end
            catch
                error('Could not retrieve EEG or ALLEEG from base workspace');
            end
        end
    else
        % Use the provided input
        EEG = varargin{1};
    end
    
    % Check if output file path was provided
    if nargin >= 2
        outputFile = varargin{2};
    else
        % Ask user for output file
        [fileName, filePath] = uiputfile({'*.txt', 'Text Files (*.txt)'; '*.*', 'All Files'}, ...
            'Save BDF File', 'eyesort_bins.txt');
        if fileName == 0
            % User cancelled
            return;
        end
        outputFile = fullfile(filePath, fileName);
    end
    
    % Initialize variables to store unique codes
    allCodes = {};
    
    % Extract all filtered event codes from the dataset(s)
    if length(EEG) > 1
        % Multiple datasets (ALLEEG)
        fprintf('Processing %d datasets...\n', length(EEG));
        
        for i = 1:length(EEG)
            if ~isempty(EEG(i)) && isfield(EEG(i), 'event') && ~isempty(EEG(i).event)
                fprintf('Extracting codes from dataset %d...\n', i);
                datasetCodes = extract_filtered_codes(EEG(i));
                allCodes = [allCodes, datasetCodes];
            end
        end
    else
        % Single dataset
        allCodes = extract_filtered_codes(EEG);
    end
    
    % Get unique codes and sort them
    uniqueCodes = unique(allCodes);
    fprintf('Found %d unique filter codes.\n', length(uniqueCodes));
    
    % Create a structure to organize filters by condition and region
    codeMap = organize_filter_codes(uniqueCodes);
    
    % Create and write the BDF file
    write_bdf_file(codeMap, outputFile);
    
    fprintf('BDF file successfully created at: %s\n', outputFile);
end

function filteredCodes = extract_filtered_codes(EEG)
    % Extract all 6-digit filtered event codes from an EEG dataset
    filteredCodes = {};
    
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end
    
    for i = 1:length(EEG.event)
        % Check for 6-digit type string (filtered events)
        if isfield(EEG.event(i), 'type') && ischar(EEG.event(i).type)
            eventType = EEG.event(i).type;
            
            % Check if this is a 6-digit code created by the filter process
            if length(eventType) == 6 && all(isstrprop(eventType, 'digit'))
                filteredCodes{end+1} = eventType;
            end
        end
    end
end

function codeMap = organize_filter_codes(uniqueCodes)
    % Organize filter codes by condition and region
    codeMap = struct();
    
    % Collect condition codes (first 2 digits)
    conditionCodes = unique(cellfun(@(x) x(1:2), uniqueCodes, 'UniformOutput', false));
    
    % For each condition code, collect regions (middle 2 digits)
    for c = 1:length(conditionCodes)
        condCode = conditionCodes{c};
        codeMap.(sprintf('cond%s', condCode)) = struct();
        
        % Find all codes for this condition
        condCodeIndices = find(cellfun(@(x) strcmp(x(1:2), condCode), uniqueCodes));
        condFilterCodes = uniqueCodes(condCodeIndices);
        
        % Extract region codes (middle 2 digits)
        regionCodes = unique(cellfun(@(x) x(3:4), condFilterCodes, 'UniformOutput', false));
        
        % For each region in this condition, collect filter codes (last 2 digits)
        for r = 1:length(regionCodes)
            regionCode = regionCodes{r};
            
            % Find all codes for this condition and region
            regionIndices = find(cellfun(@(x) strcmp(x(1:2), condCode) && strcmp(x(3:4), regionCode), uniqueCodes));
            regionFilterCodes = uniqueCodes(regionIndices);
            
            % Store all filter codes for this condition and region
            codeMap.(sprintf('cond%s', condCode)).(sprintf('region%s', regionCode)) = regionFilterCodes;
        end
    end
end

function write_bdf_file(codeMap, outputFile)
    % Write the BDF file with the appropriate format for BINLISTER
    fileID = fopen(outputFile, 'w');
    
    if fileID == -1
        error('Could not open file for writing: %s', outputFile);
    end
    
    % Write BDF header
    fprintf(fileID, 'bin descriptor file created by EyeSort plugin\n\n');
    
    % Initialize bin number
    binNum = 1;
    
    % Get all condition fields
    conditionFields = fieldnames(codeMap);
    
    % Create a region name lookup for descriptive labels
    regionNameMap = containers.Map();
    regionNameMap('01') = 'Beginning';
    regionNameMap('02') = 'PreTarget';
    regionNameMap('03') = 'Target_word';
    regionNameMap('04') = 'Ending';
    
    % Process each condition
    for c = 1:length(conditionFields)
        condField = conditionFields{c};
        condCode = regexprep(condField, 'cond', '');
        
        % Get all region fields for this condition
        regionFields = fieldnames(codeMap.(condField));
        
        % Process each region
        for r = 1:length(regionFields)
            regionField = regionFields{r};
            regionCode = regexprep(regionField, 'region', '');
            
            % Get region name for description
            regionName = '';
            if isKey(regionNameMap, regionCode)
                regionName = regionNameMap(regionCode);
            else
                regionName = sprintf('Region%s', regionCode);
            end
            
            % Get all filter codes for this condition and region
            filterCodes = codeMap.(condField).(regionField);
            
            % Format all codes with semicolons for this bin
            codesString = strjoin(filterCodes, ';');
            
            % Create descriptive bin name based on condition and region
            binDescription = sprintf('Condition %s, %s', condCode, regionName);
            
            % Write bin in BINLISTER format
            fprintf(fileID, 'Bin %d\n', binNum);
            fprintf(fileID, '%s\n', binDescription);
            fprintf(fileID, '.{%s}\n\n', codesString);
            
            binNum = binNum + 1;
        end
    end
    
    fclose(fileID);
    
    fprintf('Created %d bins in the BDF file.\n', binNum-1);
end 