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
        % No inputs provided - check for output directory from dataset loading
        outputDir = '';
        
        % Try batch output directory first
        try
            outputDir = evalin('base', 'eyesort_batch_output_dir');
            fprintf('Found batch output directory: %s\n', outputDir);
        catch
            % Try single dataset output directory
            try
                outputDir = evalin('base', 'eyesort_single_output_dir');
                fprintf('Found single dataset output directory: %s\n', outputDir);
            catch
                fprintf('No output directory found in workspace.\n');
            end
        end
        
        % If we have an output directory and it exists, use it
        if ~isempty(outputDir) && exist(outputDir, 'dir')
            fprintf('Using previously selected output directory for BDF generation.\n');
            process_from_directory(outputDir, varargin{:});
            return;
        end
        
        % Fallback: prompt user to select directory
        fprintf('Output directory not found. Please select the directory with processed/labeled datasets.\n');
        selectedDir = uigetdir('', 'Select Directory with Processed/Labeled Datasets');
        
        if isequal(selectedDir, 0)
            error('BDF generation cancelled by user');
        end
        
        process_from_directory(selectedDir, varargin{:});
        return;
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
    
    % Extract all labeled event codes and descriptions from the dataset(s)
    allDescriptions = struct();
    if length(EEG) > 1
        % Multiple datasets (ALLEEG)
        fprintf('Processing %d datasets...\n', length(EEG));
        
        for i = 1:length(EEG)
            if ~isempty(EEG(i)) && isfield(EEG(i), 'event') && ~isempty(EEG(i).event)
                fprintf('Extracting codes from dataset %d...\n', i);
                [datasetCodes, datasetDescs] = extract_labeled_codes(EEG(i));
                allCodes = [allCodes, datasetCodes];
                % Merge descriptions
                descFields = fieldnames(datasetDescs);
                for j = 1:length(descFields)
                    if ~isfield(allDescriptions, descFields{j})
                        allDescriptions.(descFields{j}) = datasetDescs.(descFields{j});
                    end
                end
            end
        end
    else
        % Single dataset
        [allCodes, allDescriptions] = extract_labeled_codes(EEG);
    end
    
    % Get unique codes and sort them
    uniqueCodes = unique(allCodes);
    fprintf('Found %d unique label codes.\n', length(uniqueCodes));
    
    % Check if we have any labeled events
    if isempty(uniqueCodes)
        error('No labeled events found. Please run labeling first.');
    end
    
    % Create a structure to organize labels by condition code and description
    codeMap = organize_label_codes(uniqueCodes, allDescriptions);
    
    % Create and write the BDF file
    write_bdf_file(codeMap, outputFile);
    
    fprintf('BDF file successfully created at: %s\n', outputFile);
end

function [labeledCodes, descriptions] = extract_labeled_codes(EEG)
    % Extract all 6-digit labeled event codes and their descriptions from an EEG dataset
    labeledCodes = {};
    descriptions = struct();
    
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end
    
    for i = 1:length(EEG.event)
        code = '';
        condDesc = '';
        labelDesc = '';
        
        % Check for eyesort_full_code field (preferred method)
        if isfield(EEG.event(i), 'eyesort_full_code') && ~isempty(EEG.event(i).eyesort_full_code)
            code = EEG.event(i).eyesort_full_code;
            % Get individual BDF descriptions if available
            if isfield(EEG.event(i), 'bdf_condition_description') && ~isempty(EEG.event(i).bdf_condition_description)
                condDesc = EEG.event(i).bdf_condition_description;
            end
            if isfield(EEG.event(i), 'bdf_label_description') && ~isempty(EEG.event(i).bdf_label_description)
                labelDesc = EEG.event(i).bdf_label_description;
            end
        % Also check for 6-digit type string (fallback method)
        elseif isfield(EEG.event(i), 'type') && ischar(EEG.event(i).type)
            eventType = EEG.event(i).type;
            % Check if this is a 6-digit code created by the label process
            if length(eventType) == 6 && all(isstrprop(eventType, 'digit'))
                code = eventType;
                if isfield(EEG.event(i), 'bdf_condition_description') && ~isempty(EEG.event(i).bdf_condition_description)
                    condDesc = EEG.event(i).bdf_condition_description;
                end
                if isfield(EEG.event(i), 'bdf_label_description') && ~isempty(EEG.event(i).bdf_label_description)
                    labelDesc = EEG.event(i).bdf_label_description;
                end
            end
        end
        
        % Store code and descriptions
        if ~isempty(code)
            labeledCodes{end+1} = code;
            fieldName = ['code_' code];
            if ~isfield(descriptions, fieldName)
                descriptions.(fieldName) = struct('condition', condDesc, 'label', labelDesc);
            end
        end
    end
end

function codeMap = organize_label_codes(uniqueCodes, descriptions)
    % Organize label codes by:
    % 1. Condition type (bdf_condition_description)
    % 2. Condition code (first 2 digits) 
    % 3. Label description (bdf_label_description)
    % This creates bins for factorial designs (e.g., 2x2, 3x2)
    codeMap = struct();
    binCounter = 1;
    
    for i = 1:length(uniqueCodes)
        code = uniqueCodes{i};
        conditionCode = code(1:2);  % First 2 digits
        
        % Get descriptions for this code
        fieldName = ['code_' code];
        if isfield(descriptions, fieldName)
            condDesc = descriptions.(fieldName).condition;
            labelDesc = descriptions.(fieldName).label;
        else
            condDesc = sprintf('Condition_%s', conditionCode);
            labelDesc = sprintf('Label_%s', code(5:6));
        end
        
        % Full description for bin
        if ~isempty(condDesc) && ~isempty(labelDesc)
            fullDesc = [condDesc ' ' labelDesc];
        elseif ~isempty(labelDesc)
            fullDesc = labelDesc;
        elseif ~isempty(condDesc)
            fullDesc = condDesc;
        else
            fullDesc = sprintf('Code_%s', code);
        end
        
        % Check if we already have this combination (conditionType + labelDescription)
        % Note: condition CODE doesn't matter, only condition TYPE (description)
        foundMatch = false;
        fields = fieldnames(codeMap);
        for j = 1:length(fields)
            existingBin = codeMap.(fields{j});
            % Must match: condition TYPE description AND label description
            % (condition CODE can differ - e.g., codes 01 and 03 both labeled "Valid")
            if strcmp(existingBin.conditionDesc, condDesc) && ...
               strcmp(existingBin.labelDesc, labelDesc)
                % Add to existing bin
                codeMap.(fields{j}).codes{end+1} = code;
                foundMatch = true;
                break;
            end
        end
        
        % If no match, create new bin
        if ~foundMatch
            binKey = sprintf('bin%03d', binCounter);
            codeMap.(binKey) = struct(...
                'conditionCode', conditionCode, ...
                'conditionDesc', condDesc, ...
                'labelDesc', labelDesc, ...
                'fullDesc', fullDesc, ...
                'codes', {{code}});
            binCounter = binCounter + 1;
        end
    end
end

function write_bdf_file(codeMap, outputFile)
    % Write the BDF file with the appropriate format for BINLISTER
    fileID = fopen(outputFile, 'w');
    
    if fileID == -1
        error('Could not open file for writing: %s', outputFile);
    end
    
    % Get all bin fields
    binFields = fieldnames(codeMap);
    
    % Sort bin fields to ensure consistent output order
    binFields = sort(binFields);
    
    % Process each bin
    for i = 1:length(binFields)
        binField = binFields{i};
        binData = codeMap.(binField);
        
        % Sort codes within bin to ensure consistent order
        binCodes = sort(binData.codes);
        
        % Create the codes string with semicolon separation
        codesString = strjoin(binCodes, '; ');
        
        % Write bin in BINLISTER format
        fprintf(fileID, 'Bin %d\n', i);
        fprintf(fileID, '%s\n', binData.fullDesc);
        fprintf(fileID, '.{%s}\n\n', codesString);
    end
    
    fclose(fileID);
    
    fprintf('Created %d bins in the BDF file.\n', length(binFields));
end

function process_from_directory(directory, varargin)
    % Memory-efficient: process datasets from files one-at-a-time
    fprintf('Processing datasets from directory (memory-efficient mode)...\n');
    fprintf('Looking in: %s\n', directory);
    
    % Find all processed dataset files - try multiple patterns
    processedFiles = dir(fullfile(directory, '*_processed.set'));
    if isempty(processedFiles)
        % Try other patterns
        processedFiles = dir(fullfile(directory, '*_labeled.set'));
    end
    if isempty(processedFiles)
        processedFiles = dir(fullfile(directory, '*.set'));
    end
    if isempty(processedFiles)
        error('No .set files found in: %s', directory);
    end
    
    fprintf('Found %d dataset files\n', length(processedFiles));
    
    % Get output file path
    if nargin >= 2 && ~isempty(varargin{1})
        outputFile = varargin{1};
    else
        [fileName, filePath] = uiputfile({'*.txt', 'Text Files (*.txt)'; '*.*', 'All Files'}, ...
            'Save BDF File', 'eyesort_bins.txt');
        if fileName == 0
            return;
        end
        outputFile = fullfile(filePath, fileName);
    end
    
    % Extract codes and descriptions from each file (one-at-a-time)
    allCodes = {};
    allDescriptions = struct();
    for i = 1:length(processedFiles)
        fullPath = fullfile(processedFiles(i).folder, processedFiles(i).name);
        fprintf('  Processing: %s\n', processedFiles(i).name);
        
        try
            % Load only this dataset (use full path without 'filename' parameter)
            tempEEG = pop_loadset(fullPath);
            
            % Extract codes and descriptions
            [datasetCodes, datasetDescs] = extract_labeled_codes(tempEEG);
            allCodes = [allCodes, datasetCodes];
            
            % Merge descriptions
            descFields = fieldnames(datasetDescs);
            for j = 1:length(descFields)
                if ~isfield(allDescriptions, descFields{j})
                    allDescriptions.(descFields{j}) = datasetDescs.(descFields{j});
                end
            end
            
            % Clear from memory immediately
            clear tempEEG;
        catch ME
            warning('Failed to process %s: %s', processedFiles(i).name, ME.message);
        end
    end
    
    % Get unique codes
    uniqueCodes = unique(allCodes);
    fprintf('Found %d unique label codes.\n', length(uniqueCodes));
    
    if isempty(uniqueCodes)
        error('No labeled events found in processed datasets.');
    end
    
    % Generate BDF file
    codeMap = organize_label_codes(uniqueCodes, allDescriptions);
    write_bdf_file(codeMap, outputFile);
    
    fprintf('BDF file successfully created at: %s\n', outputFile);
end 