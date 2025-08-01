function cleanup_temp_files(batchFilePaths)
% CLEANUP_TEMP_FILES - Clean up temporary files created during processing
%
% Usage:
%   cleanup_temp_files(batchFilePaths)
%
% Inputs:
%   batchFilePaths - Cell array of file paths to clean up

batch_label_utils('cleanup', batchFilePaths);
end 