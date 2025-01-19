eeglab;

EEG = pop_loadset('filename', 'WTS011_sync.set', 'filepath', './datasets');

disp(EEG);

events = EEG.event; 

disp(events);