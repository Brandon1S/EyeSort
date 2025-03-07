function main()
    
    startCode = 'S254';
    endCode = 'S255';
    conditionTriggers = {'S211', 'S213', 'S221', 'S223'};  % adjust as needed
    itemTriggers = cell(1, 112);
    for i = 1:112
        itemTriggers{i} = ['S' num2str(i)];  % Add 'S' prefix to each number
    end
    
    offset = 488;  % Starting position offset in pixels
    pxPerChar = 11;  % Pixels per character
    numRegions = 4;  % Number of regions in each stimulus
    regionNames = {'Beginning', 'PreTarget', 'Target_word', 'Ending'};
    
    % Initialize column names without $ prefix
    conditionColName = 'trigcondition';
    itemColName = 'trigitem';
    txtFilePath = '/Users/brandon/Datasets/Electric_Eyel_V2_Datasource_IAs.txt';
    %txtFilePath = '/Users/brandon/Datasets/RLGL Datasource with IAs NoFigTrig.txt';
    % Read the data file to check column names
    opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
    opts.VariableNamingRule = 'preserve';  % Preserve original column names
    data = readtable(txtFilePath, opts);
    
    % Debug: Print column names and first few rows
    fprintf('Available columns in data:\n');
    disp(data.Properties.VariableNames);
    fprintf('First few rows of data:\n');
    disp(head(data));
    
    % Check if we need to add $ prefix to column names
    if ~ismember(conditionColName, data.Properties.VariableNames)
        conditionColName = ['$' conditionColName];
    end
    if ~ismember(itemColName, data.Properties.VariableNames)
        itemColName = ['$' itemColName];
    end
    
    % Define input and output directories
    inputDir = '/Users/brandon/Datasets/Electric_Datasets';
    %inputDir = '/Users/brandon/Datasets/RedLightGreenLight_Datasets';
    outputDir = fullfile(inputDir, 'processed');
    
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
        fprintf('Created output directory: %s\n', outputDir);
    end
    
    % Get list of all .set files in input folder
    files = dir(fullfile(inputDir, '*.set'));
    
    % Process each dataset
    for i = 1:length(files)
        try
            fprintf('Processing dataset %d/%d: %s\n', i, length(files), files(i).name);
            
            % Load dataset
            EEG = pop_loadset('filename', files(i).name, 'filepath', inputDir);
            
            % Debug: Check initial EEG structure
            fprintf('Initial EEG structure - Events: %d, Channels: %d\n', length(EEG.event), EEG.nbchan);
            
            % Apply text-based interest area computation
            EEG = combined_compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                                      numRegions, regionNames, ...
                                                      conditionColName, itemColName, startCode, endCode, conditionTriggers, itemTriggers);
            
            % Debug: Check EEG structure after IA computation
            fprintf('After IA computation - Events: %d\n', length(EEG.event));
            
            % Apply trial labeling with debug flag
            EEG = behavior_trial_labeling(EEG, startCode, endCode, ...
                                                conditionTriggers, itemTriggers); 
            
            % Debug: Check final structure
            if isfield(EEG.event, 'type')
                types = {EEG.event.type};
                fprintf('Event types present: %s\n', strjoin(unique(types), ', '));
            end
            
            % Save processed dataset with new suffix
            [~, name, ~] = fileparts(files(i).name);
            newname = fullfile(outputDir, [name '_processed.set']);
            pop_saveset(EEG, 'filename', newname);
            
            fprintf('Successfully processed and saved: %s\n', newname);
            
        catch ME
            warning('Error processing %s: %s\n Stack trace:', files(i).name, ME.message);
            disp(getReport(ME, 'extended'));
            continue;
        end
    end
    
    fprintf('Processing complete.\n');
end