%% EYESORT_BATCH_PROCESS - Simple batch processing script
%
% This script processes all .set files in a folder through the EyeSort pipeline.
% Edit the paths below and run the script.

% Set your paths here
datasetFolder = '/Users/brandon/Datasets/Electric_Datasets_Small';
config_file = '/Users/brandon/Datasets/electric_eyel_config.mat';  % UPDATE THIS PATH

% Optional: separate label config file (leave empty to skip labeling)
filter_config_file = '/Users/brandon/Datasets/electric_eyel_filters.mat';  % e.g., '/path/to/filter_config.m' or leave empty

% Optional: save intermediate datasets after text IA processing (before labeling)
save_intermediate = true;  % Set to true to save datasets with boundaries/labeling but no labeling

% Find datasets
datasetFiles = dir(fullfile(datasetFolder, '*.set'));
if isempty(datasetFiles)
    error('No .set files found in: %s', datasetFolder);
end

fprintf('Found %d dataset(s) to process\n', length(datasetFiles));

% Process each dataset
for i = 1:length(datasetFiles)
    datasetPath = fullfile(datasetFiles(i).folder, datasetFiles(i).name);
    fprintf('\n=== Processing %d/%d: %s ===\n', i, length(datasetFiles), datasetFiles(i).name);
    
    try
        % Load dataset
        EEG = pop_loadset(datasetPath);
        
        % Step 1: Compute interest areas (includes trial labeling)
        EEG = compute_text_based_ia(EEG, config_file);
        
        % Optional: Save intermediate dataset (after IA processing, before labeling)
        if save_intermediate
            [~, name, ~] = fileparts(datasetFiles(i).name);
            intermediatePath = fullfile(datasetFolder, [name '_eyesort_ia.set']);
            pop_saveset(EEG, intermediatePath);
            fprintf('Intermediate dataset saved: %s\n', [name '_eyesort_ia.set']);
        end
        
        % Step 2: Apply filters (if specified)
        if ~isempty(filter_config_file)
            EEG = label_datasets_core(EEG, filter_config_file);
        else
            % Try to use same config file for labeling (will skip if no labeling params)
            EEG = label_datasets_core(EEG, config_file);
        end
        
        % Save processed dataset
        [~, name, ~] = fileparts(datasetFiles(i).name);
        outputPath = fullfile(datasetFolder, [name '_eyesort_processed.set']);
        pop_saveset(EEG, outputPath);
        
        fprintf('Dataset %d processed successfully!\n', i);
        
    catch ME
        fprintf('ERROR processing dataset %d: %s\n', i, ME.message);
    end
end

fprintf('\nBatch processing complete!\n'); 

% Summary
successCount = 0;
intermediateCount = 0;
for i = 1:length(datasetFiles)
    outputPath = fullfile(datasetFolder, [datasetFiles(i).name(1:end-4) '_eyesort_processed.set']);
    if exist(outputPath, 'file')
        successCount = successCount + 1;
    end
    if save_intermediate
        intermediatePath = fullfile(datasetFolder, [datasetFiles(i).name(1:end-4) '_eyesort_ia.set']);
        if exist(intermediatePath, 'file')
            intermediateCount = intermediateCount + 1;
        end
    end
end

fprintf('\n=== BATCH PROCESSING SUMMARY ===\n');
fprintf('Total datasets found: %d\n', length(datasetFiles));
fprintf('Successfully processed: %d\n', successCount);
if save_intermediate
    fprintf('Intermediate saves: %d\n', intermediateCount);
end
fprintf('Failed: %d\n', length(datasetFiles) - successCount);
fprintf('Output folder: %s\n', datasetFolder);
fprintf('===================================\n'); 