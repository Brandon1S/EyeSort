function mainSuperGUI()
    % Define the proportions of elements in each row
    g = [1 1 1 0.5];

    % Define the layout (geometry) of the GUI
    geometry = { g g 1 };
    
    % Define the UI elements for the GUI
    uilist = { ...
        % First row: Input EEG datasets
        {'Style', 'text', 'string', 'Load EEG Datasets', 'FontSize', 12}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', '...', 'callback', @browseForEEG}, ...
        ...
        {'Style', 'text', 'string', 'Load AOIs', 'FontSize', 12}, ...
        {}, ...
        {}, ...
        {'Style', 'pushbutton', 'string', '...', 'callback', @browseForAOI}, ...
        ...
        {'Style', 'pushbutton', 'string', 'Close', 'callback', @(~,~) close(gcf)} ...
    };

    % Call inputgui to create the GUI
    [tmp1, tmp2, strhalt, structout] = inputgui(geometry, uilist, ...
        'pophelp(''mainSuperGUI'');', 'BinMaster');
end

% Callback function to browse for EEG datasets
function browseForEEG(~, ~)
    
    [file, path] = uigetfile({'*.set', 'EEG Dataset (*.set)'; '*.*', 'All Files (*.*)'}, ...
                             'Select EEG Dataset');
    if isequal(file, 0)
        
        disp('No EEG dataset selected.');
    
    else
        
        fullFilePath = fullfile(path, file);
        
        disp(['Selected EEG dataset: ', fullFilePath]);
        
        % Attempt to load the EEG dataset
        try
            
            EEG = pop_loadset('filename', file, 'filepath', path);
            
            assignin('base', 'EEG', EEG); % Save the EEG variable to the base workspace
            
            disp('EEG dataset loaded successfully.');
        
        catch ME
            
            disp(['Error loading EEG dataset: ', ME.message]);
        end
    end
end

% Callback function to browse for AOIs .txt file
function browseForAOI(~, ~)
    
    [file, path] = uigetfile({'*.txt', 'Text Files (*.txt)'; '*.*', 'All Files (*.*)'}, ...
                             'Select AOI File');
    
    if isequal(file, 0)
        
        disp('No AOI file selected.');
   
    else
        
        fullFilePath = fullfile(path, file);
       
        disp(['Selected AOI file: ', fullFilePath]);

        % Load the AOI file and process it
        try
       
            AOIData = readtable(fullFilePath, 'FileType', 'text');
       
            assignin('base', 'AOIData', AOIData); % Save AOI data to the base workspace
       
            disp('AOI file loaded successfully.');
       
        catch ME
       
            disp(['Error loading AOI file: ', ME.message]);
        end
    end
end
