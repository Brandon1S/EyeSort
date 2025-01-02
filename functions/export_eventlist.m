function export_eventlist(eventinfo, filepath)
    fid = fopen(filepath, 'w');
    fprintf(fid, 'EventNum\tEventCode\tBin\n');
    for i = 1:length(eventinfo)
        fprintf(fid, '%d\t%d\t%d\n', i, eventinfo(i).code, eventinfo(i).bini);
    end
    fclose(fid);
end
