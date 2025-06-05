function masterTableFinal(config)
    % Initialize the master table
    masterTable = table;
    masterTableName = config.Name;
    fprintf('Creating master table "%s".\n', masterTableName);

    % Loop through each file in the config
    for stepIdx = 1:size(config.steps, 1)
        dataFile = config.steps{stepIdx, 1};
        groupName = detectGroupName(dataFile);

        % Load data from Cytosim file using the known working function
        cytosimTable = cytosimTableFinal(dataFile); % Must be in path

        % Extract Time once and only once
        if ~ismember('Time', masterTable.Properties.VariableNames)
            masterTable.Time = cytosimTable.Time;
        end

        % Prepare group subtable
        groupSubtable = table;

        % Explode all non-Time variables
        varNames = cytosimTable.Properties.VariableNames;
        varNames(strcmp(varNames, 'Time')) = [];

        % Determine number of time points
        nFrames = height(cytosimTable);

        % For each variable (e.g., posX, class, etc.)
        for v = 1:length(varNames)
            var = varNames{v};

            % Get all data across frames
            allVals = cytosimTable.(var);

            % Preallocate based on max column size
            maxLength = max(cellfun(@(x) size(x, 2), allVals));

            % Initialize matrix
            varMatrix = nan(nFrames, maxLength);

            for t = 1:nFrames
                val = allVals{t};
                if ~isempty(val)
                    val = val(:).';  % ensure row vector
                    len = numel(val);
                    varMatrix(t, 1:len) = val;
                end
            end

            % Assign to groupSubtable
            groupSubtable.(var) = varMatrix;
        end

        % Assign exploded group as subtable
        masterTable.(groupName) = groupSubtable;
        fprintf('Group "%s" added.\n', groupName);
    end

    % Place result in base workspace
    assignin('base', masterTableName, masterTable);
    fprintf('Final master table "%s" is now in workspace.\n', masterTableName);
end

function groupName = detectGroupName(dataFile)
    % Reads group name from cytosim text file
    text = fileread(dataFile);
    match = regexp(text, '% report (\w+):', 'tokens', 'once');

    if ~isempty(match)
        groupName = match{1};
    else
        groupName = 'UnknownGroup';
    end

    if ~contains(text, 'identity')
        groupName = [groupName, 'Average'];
    end
end
