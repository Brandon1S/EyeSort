function help_button()
    % Function to display help information for EyeSort
    % Called when the user clicks the "Help" button in the EyeSort menu
    
    % Find the plugin directory
    pluginDir = fileparts(which('eegplugin_eyesort'));
    
    % Path to help file
    helpFile = fullfile(pluginDir, 'help.txt');
    
    % Check if help file exists
    if ~exist(helpFile, 'file')
        errordlg('Help file not found. Please check your installation.', 'EyeSort Help Error');
        return;
    end
    
    % Read the contents of the help file
    try
        fid = fopen(helpFile, 'r');
        if fid == -1
            errordlg('Could not open help file.', 'EyeSort Help Error');
            return;
        end
        
        helpContent = textscan(fid, '%s', 'Delimiter', '\n');
        helpContent = helpContent{1};
        fclose(fid);
        
        % Convert cell array of lines to a single string
        helpText = '';
        for i = 1:length(helpContent)
            helpText = [helpText, helpContent{i}, char(10)]; % char(10) is newline
        end
        
        % Create a figure for the help window
        hFig = figure('Name', 'EyeSort Help', ...
               'NumberTitle', 'off', ...
               'MenuBar', 'none', ...
               'ToolBar', 'none', ...
               'Position', [300, 300, 600, 400], ...
               'Color', [0.95, 0.95, 0.95]);
        
        % Create text area with help content
        uicontrol('Parent', hFig, ...
                 'Style', 'edit', ...
                 'String', helpText, ...
                 'Position', [20, 60, 560, 320], ...
                 'Max', 2, ... % Make it multiline
                 'Min', 0, ...
                 'HorizontalAlignment', 'left', ...
                 'Enable', 'inactive', ... % Make it read-only but selectable
                 'BackgroundColor', [1, 1, 1]);
        
        % Add a close button
        uicontrol('Parent', hFig, ...
                 'Style', 'pushbutton', ...
                 'String', 'Close', ...
                 'Position', [250, 20, 100, 30], ...
                 'Callback', @(~,~) close(hFig));
                 
    catch ME
        errordlg(['Error displaying help: ' ME.message], 'EyeSort Help Error');
    end
end 