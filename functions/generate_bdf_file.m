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
    % Organize label codes by event type (last 4 digits: region + label)
    codeMap = struct();
    
    % Extract unique event types (last 4 digits)
    eventTypes = unique(cellfun(@(x) x(3:6), uniqueCodes, 'UniformOutput', false));
    
    % For each event type, collect all condition codes that have this event type
    for i = 1:length(eventTypes)
        eventType = eventTypes{i};
        
        % Find all codes that end with this event type
        eventTypeIndices = find(cellfun(@(x) strcmp(x(3:6), eventType), uniqueCodes));
        eventTypeCodes = uniqueCodes(eventTypeIndices);
        
        % Store all codes for this event type
        codeMap.(sprintf('event%s', eventType)) = eventTypeCodes;
    end
end

function write_bdf_file(codeMap, outputFile)
    % Write the BDF file with the appropriate format for BINLISTER
    fileID = fopen(outputFile, 'w');
    
    if fileID == -1
        error('Could not open file for writing: %s', outputFile);
    end
    
    % Initialize bin number
    binNum = 1;
    
    % Get all event type fields
    eventFields = fieldnames(codeMap);
    
    % Sort event fields to ensure consistent output order
    eventFields = sort(eventFields);
    
    % Process each event type
    for i = 1:length(eventFields)
        eventField = eventFields{i};
        
        % Get all codes for this event type
        eventCodes = codeMap.(eventField);
        
        % Sort codes to ensure consistent order
        eventCodes = sort(eventCodes);
        
        % Get description from the first code (they should all have same event type description)
        detailedDescription = sprintf('Event Type %s', regexprep(eventField, 'event', ''));
        
        % Try to get BDF full description from workspace
        try
            EEG_workspace = evalin('base', 'EEG');
            for j = 1:length(EEG_workspace.event)
                evt = EEG_workspace.event(j);
                if isfield(evt, 'eyesort_full_code') && ~isempty(evt.eyesort_full_code)
                    % Check if this event matches any of our codes
                    if any(strcmp(evt.eyesort_full_code, eventCodes))
                        if isfield(evt, 'bdf_full_description') && ~isempty(evt.bdf_full_description)
                            detailedDescription = evt.bdf_full_description;
                            break;
                        end
                    end
                end
            end
        catch
            % Use default description if BDF fields can't be accessed
        end
        
        % Create the codes string with semicolon separation
        codesString = strjoin(eventCodes, '; ');
        
        % Write bin in BINLISTER format
        fprintf(fileID, 'Bin %d\n', binNum);
        fprintf(fileID, '%s\n', detailedDescription);
        fprintf(fileID, '.{%s}\n\n', codesString);
        
        binNum = binNum + 1;
    end
    
    fclose(fileID);
    
    fprintf('Created %d bins in the BDF file.\n', binNum-1);
end 