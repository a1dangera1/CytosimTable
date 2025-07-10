function output = doNotOpen(dataFileName)
    % Read file content
    text = fileread(dataFileName);

    % Define possible variable prefixes
    possible_prefixes = {'class', 'fib_type', 'count', 'delta_time', 'fiber_end', 'identity'};
    pattern = sprintf('%%\\s*(%s)[^\\n]*', strjoin(possible_prefixes, '|'));

    % Extract the variable names line
    var_names_line = regexp(text, pattern, 'match', 'once');
    if isempty(var_names_line)
        error('Variable names line not found.');
    end

    % Extract variable names, excluding the leading "%"
    var_names = regexp(strtrim(var_names_line(2:end)), '\S+', 'match');

    % Detect identity column
    identity_idx = find(strcmp(var_names, 'identity'), 1);
    has_identity = ~isempty(identity_idx);

    % Rename class to classname if identity is not present
    class_idx = find(strcmp(var_names, 'class'), 1);
    if ~has_identity && ~isempty(class_idx)
        var_names{class_idx} = 'classname';
    end

    % Extract time points
    times = str2double(regexp(text, '(?<=time )[^\n]+(?=\n)', 'match')).';

    % Split into frames
    frames = regexp(text, '% frame\s+\d+.+?(?=% frame|\Z)', 'match', 'dotall');
    if isempty(frames)
        error('No frames found in the input file.');
    end

    % Initialize table
    T = table;
    T.Time = times;

    % Preallocate empty arrays
    for j = 1:numel(var_names)
        T.(var_names{j}) = cell(length(times), 1);
    end

    % Determine max identity
    max_identity = 0;
    if has_identity
        for i = 1:length(frames)
            lines = strsplit(frames{i}, '\n');
            data_lines = lines(~startsWith(strtrim(lines), '%'));
            for line = data_lines
                row = sscanf(line{1}, '%f').';
                if ~isempty(row) && numel(row) >= identity_idx
                    max_identity = max(max_identity, row(identity_idx));
                end
            end
        end
        max_identity = max(1, round(max_identity));
    end

    % Process frames
    for i = 1:length(frames)
        lines = strsplit(frames{i}, '\n');
        data_lines = lines(~startsWith(strtrim(lines), '%'));
        raw_rows = cellfun(@(l) regexp(strtrim(l), '\S+', 'match'), data_lines, 'UniformOutput', false);

        % Handle text (classname) separately
        if ~has_identity && ~isempty(class_idx)
            classnames = cellfun(@(r) r{class_idx}, raw_rows, 'UniformOutput', false);
            T.classname{i} = classnames(:); % column vector of strings
        end

        % Extract and convert to numeric
        numeric_data = [];
        for k = 1:length(raw_rows)
            nums = str2double(raw_rows{k});
            if any(~isnan(nums))
                numeric_data = [numeric_data; nums];
            end
        end

        if has_identity
            % Initialize full matrix with NaNs
            frame_data = nan(max_identity, numel(var_names));
            for r = 1:size(numeric_data, 1)
                id = numeric_data(r, identity_idx);
                if id >= 1 && id <= max_identity
                    frame_data(id, :) = numeric_data(r, :);
                end
            end
            for j = 1:numel(var_names)
                if j <= size(frame_data, 2)
                    T.(var_names{j}){i} = frame_data(:, j).'; % 1×N row vector
                else
                    T.(var_names{j}){i} = nan(1, max_identity);
                end
            end
        else
            for j = 1:numel(var_names)
                if strcmp(var_names{j}, 'classname')
                    continue;
                elseif j <= size(numeric_data, 2)
                    T.(var_names{j}){i} = numeric_data(:, j); % matrix column
                else
                    T.(var_names{j}){i} = nan(size(numeric_data, 1), 1);
                end
            end
        end
    end

    % Output final table
    output = T;
end
