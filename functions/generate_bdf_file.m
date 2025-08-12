function generate_bdf_file(varargin)
% GENERATE_BDF_FILE - Creates a BINLISTER Bin Descriptor File from EyeSort labeled datasets
%
% Usage:
%   >> generate_bdf_file;                     % Interactive mode with dialog
%   >> generate_bdf_file(EEG);                % Generate BDF from single EEG dataset
%   >> generate_bdf_file(ALLEEG);             % Generate BDF from ALLEEG structure
%   >> generate_bdf_file(EEG, outputFile);    % Specify output file path
%
% Inputs:
%   EEG        - EEGLAB EEG structure with labeled events (optional)
%   ALLEEG     - EEGLAB ALLEEG structure containing labeled datasets (optional)
%   outputFile - Full path to output BDF file (optional)
%
% This function analyzes the 6-digit label codes in labeled datasets and
% automatically generates a BINLISTER compatible bin descriptor file (BDF).
% The 6-digit codes follow this pattern:
%   - First 2 digits: Condition code (00-99)
%   - Middle 2 digits: Region code (01-99)
%   - Last 2 digits: Label code (01-99)
%
% See also: pop_label_datasets

    % Check for input arguments
    if nargin < 1
        % No inputs provided, try base workspace first
        try
            % First try to get single EEG dataset (preferred for single dataset mode)
            try
                EEG = evalin('base', 'EEG');
                fprintf('Found single EEG dataset in workspace\n');
            catch
                % Fall back to ALLEEG for multiple datasets
                ALLEEG = evalin('base', 'ALLEEG');
                if ~isempty(ALLEEG) && length(ALLEEG) >= 1
                    fprintf('Found ALLEEG with %d datasets in workspace\n', length(ALLEEG));
                    EEG = ALLEEG; % Use ALLEEG as the dataset array
                else
                    error('No valid EEG datasets found');
                end
            end
            

        catch
            error('Could not retrieve datasets from base workspace');
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
    
    % Extract all labeled event codes from the dataset(s)
    if length(EEG) > 1
        % Multiple datasets (ALLEEG)
        fprintf('Processing %d datasets...\n', length(EEG));
        
        for i = 1:length(EEG)
            if ~isempty(EEG(i)) && isfield(EEG(i), 'event') && ~isempty(EEG(i).event)
                fprintf('Extracting codes from dataset %d...\n', i);
                datasetCodes = extract_labeled_codes(EEG(i));
                allCodes = [allCodes, datasetCodes];
            end
        end
    else
        % Single dataset
        allCodes = extract_labeled_codes(EEG);
    end
    
    % Get unique codes and sort them
    uniqueCodes = unique(allCodes);
    fprintf('Found %d unique label codes.\n', length(uniqueCodes));
    
    % Check if we have any labeled events
    if isempty(uniqueCodes)
        error('No labeled events found. Please run labeling first.');
    end
    
    % Create a structure to organize labels by condition and region
    codeMap = organize_label_codes(uniqueCodes);
    
    % Create and write the BDF file
    write_bdf_file(codeMap, outputFile);
    
    fprintf('BDF file successfully created at: %s\n', outputFile);
end

function labeledCodes = extract_labeled_codes(EEG)
    % Extract all 6-digit labeled event codes from an EEG dataset
    labeledCodes = {};
    
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end
    
    for i = 1:length(EEG.event)
        % Check for eyesort_full_code field (preferred method)
        if isfield(EEG.event(i), 'eyesort_full_code') && ~isempty(EEG.event(i).eyesort_full_code)
            labeledCodes{end+1} = EEG.event(i).eyesort_full_code;
        % Also check for 6-digit type string (fallback method)
        elseif isfield(EEG.event(i), 'type') && ischar(EEG.event(i).type)
            eventType = EEG.event(i).type;
            % Check if this is a 6-digit code created by the label process
            if length(eventType) == 6 && all(isstrprop(eventType, 'digit'))
                labeledCodes{end+1} = eventType;
            end
        end
    end
end

function codeMap = organize_label_codes(uniqueCodes)
    % Organize label codes by condition and region
    codeMap = struct();
    
    % Collect condition codes (first 2 digits)
    conditionCodes = unique(cellfun(@(x) x(1:2), uniqueCodes, 'UniformOutput', false));
    
    % For each condition code, collect regions (middle 2 digits)
    for c = 1:length(conditionCodes)
        condCode = conditionCodes{c};
        codeMap.(sprintf('cond%s', condCode)) = struct();
        
        % Find all codes for this condition
        condCodeIndices = find(cellfun(@(x) strcmp(x(1:2), condCode), uniqueCodes));
        condLabelCodes = uniqueCodes(condCodeIndices);
        
        % Extract region codes (middle 2 digits)
        regionCodes = unique(cellfun(@(x) x(3:4), condLabelCodes, 'UniformOutput', false));
        
        % For each region in this condition, collect label codes (last 2 digits)
        for r = 1:length(regionCodes)
            regionCode = regionCodes{r};
            
            % Find all codes for this condition and region
            regionIndices = find(cellfun(@(x) strcmp(x(1:2), condCode) && strcmp(x(3:4), regionCode), uniqueCodes));
            regionLabelCodes = uniqueCodes(regionIndices);
            
            % Store all label codes for this condition and region
            codeMap.(sprintf('cond%s', condCode)).(sprintf('region%s', regionCode)) = regionLabelCodes;
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
    
    % Process each condition
    for c = 1:length(conditionFields)
        condField = conditionFields{c};
        condCode = regexprep(condField, 'cond', '');
        
        % Get all region fields for this condition
        regionFields = fieldnames(codeMap.(condField));
        
        % Process each region
        for r = 1:length(regionFields)
            regionField = regionFields{r};
            
            % Get all label codes for this condition and region
            labelCodes = codeMap.(condField).(regionField);
            
            % Process each label code to create detailed description
            for f = 1:length(labelCodes)
                currentCode = labelCodes{f};
                
                % Default description
                detailedDescription = sprintf('Condition %s', condCode);
                
                % Use BDF full description if available (our concatenation)
                try
                    EEG_workspace = evalin('base', 'EEG');
                    for i = 1:length(EEG_workspace.event)
                        evt = EEG_workspace.event(i);
                        if isfield(evt, 'eyesort_full_code') && strcmp(evt.eyesort_full_code, currentCode) && ...
                           isfield(evt, 'bdf_full_description') && ~isempty(evt.bdf_full_description)
                            detailedDescription = evt.bdf_full_description;
                            break;
                        end
                    end
                catch
                    % Use default description if BDF fields can't be accessed
                end
                
                % Write bin in BINLISTER format with the detailed description
                fprintf(fileID, 'Bin %d\n', binNum);
                fprintf(fileID, '%s\n', detailedDescription);
                fprintf(fileID, '.{%s}\n\n', currentCode);
                
                binNum = binNum + 1;
            end
        end
    end
    
    fclose(fileID);
    
    fprintf('Created %d bins in the BDF file.\n', binNum-1);
end 