function [processed_count, com] = batch_apply_filters(batchFilePaths, batchFilenames, outputDir, filter_config)
% BATCH_APPLY_FILTERS - Apply filter configuration to multiple datasets
%
% Usage:
%   [processed_count, com] = batch_apply_filters(batchFilePaths, batchFilenames, outputDir, filter_config)
%
% Inputs:
%   batchFilePaths  - Cell array of full file paths to datasets
%   batchFilenames  - Cell array of filenames (for display)
%   outputDir       - Output directory for filtered datasets
%   filter_config   - Filter configuration structure
%
% Outputs:
%   processed_count - Number of successfully processed datasets
%   com            - Command string for EEGLAB history

[processed_count, com] = batch_filter_utils('apply', batchFilePaths, batchFilenames, outputDir, filter_config);
end 