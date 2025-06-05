function processMasterTables(directoryPath, outputName)
    % processMasterTables2 - Processes subfolders of Cytosim data and appends
    % master tables into a uniform struct array.
    %
    % INPUTS:
    %   directoryPath - path containing subfolders of .txt Cytosim files
    %   outputName    - name for the resulting struct array variable in the base workspace
    %
    % Each entry in the struct will have:
    %   .Time         - array of time points
    %   .solid        - table with frame-wise matrices (e.g., cenX, cenY, class, identity)
    %   .couple       - same as solid (if present)

    % Check folder validity
    if ~isfolder(directoryPath)
        error('The specified directory does not exist.');
    end

    % Get all valid subfolders
    subfolders = dir(directoryPath);
    subfolders = subfolders([subfolders.isdir]);
    subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

    % Initialize output
    combinedStructArray = [];  % Delay initialization until first valid entry
    structIndex = 1;

    for i = 1:length(subfolders)
        subfolderPath = fullfile(directoryPath, subfolders(i).name);
        fprintf('Processing folder: %s\n', subfolderPath);

        % Get .txt files in subfolder
        txtFiles = dir(fullfile(subfolderPath, '*.txt'));
        if isempty(txtFiles)
            fprintf('No .txt files in "%s". Skipping.\n', subfolderPath);
            continue;
        end

        % Build config for masterTableFinal
        config.Name = 'tempMasterTable';
        config.steps = cell(length(txtFiles), 1);
        for j = 1:length(txtFiles)
            config.steps{j} = fullfile(subfolderPath, txtFiles(j).name);
        end

        % Run masterTableFinal
        masterTableFinal(config);

        % Get the resulting master table
        if evalin('base', "exist('tempMasterTable', 'var')")
            masterTable = evalin('base', 'tempMasterTable');
            evalin('base', 'clear tempMasterTable');
        else
            fprintf('Failed to retrieve tempMasterTable. Skipping.\n');
            continue;
        end

        % Build struct entry
        entry = struct();
        entry.Time = masterTable.Time;

        otherVars = setdiff(masterTable.Properties.VariableNames, {'Time'});
        for k = 1:numel(otherVars)
            field = otherVars{k};
            entry.(field) = masterTable.(field);
        end

        % Append with consistent field layout
        if isempty(combinedStructArray)
            combinedStructArray = repmat(entry, 1, 1);  % Initialize with first entry
        else
            % Add missing fields to entry
            existingFields = fieldnames(combinedStructArray);
            entryFields = fieldnames(entry);

            for f = 1:numel(existingFields)
                if ~isfield(entry, existingFields{f})
                    entry.(existingFields{f}) = [];
                end
            end

            % Add missing fields to prior structs
            for f = 1:numel(entryFields)
                if ~isfield(combinedStructArray, entryFields{f})
                    [combinedStructArray.(entryFields{f})] = deal([]);
                end
            end

            combinedStructArray(end+1) = entry;
        end
    end

    % Save to base workspace
    assignin('base', outputName, combinedStructArray);
    fprintf(' Struct array "%s" is now in the base workspace.\n', outputName);
end
