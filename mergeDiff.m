function [unique] = mergeDiff(oldModel, newModel, merge)
%mergeDiff Simple diff of two Simulink models, hilighting differences.
% UNIQUE = mergeDiff(OLDMODEL, NEWMODEL{, MERGE = false}) compares block
% names and mask parameters from two similar models.
% The differences are reported in a format based on the unified format:
% http://en.wikipedia.org/wiki/Diff_utility#Unified_format
%
% If MERGE=true then OLDMODEL will be updated with parameter values and
% missing blocks from NEWMODEL.
% The merged model requires manual editing to complete the merge process.
% The blocks in the merged model are color coded upon completion.
% This function does not examine connecting lines.  The user should review
% and connect these colored blocks manually to complete the merge.
%
%  White - Block is unchanged
%  Green - Block was missing from OLDMODEL and was copied from NEWMODEL
%  Orange - Block's parameters were updated
%  Red - Block is missing from NEWMODEL
%  Yellow - Subsystem contains modifications
%
% Returns names of blocks unique to OLDMODEL.
%
% EXAMPLE
% % List differences between two Simulink models:
% open_system('oldmodel');
% open_system('newmodel');
% mergeDiff('oldmodel', 'newmodel');
%
% Carl Osterwisch, September 2014

    if ~exist('merge', 'var')
        merge = false; % Whether to merge newModel into oldModel
    end

    newModel = getfullname(newModel); % convert any handles into names
    oldModel = getfullname(oldModel);
    fprintf(1, '--- %s\n', oldModel); % original
    fprintf(1, '+++ %s\n', newModel); % new
    newBlocks = find_system(newModel, 'LookUnderMasks', 'all', 'type', 'block');
    blocks = strrep(newBlocks, newModel, oldModel); % oldModel blocks to examine
    oldBlocks = find_system(oldModel, 'LookUnderMasks', 'all', 'type', 'block');
    ignoreBlock = '_';  % don't ignore any blocks
    for i = 1:length(blocks)
        blockName = regexprep(blocks{i}(length(oldModel)+1:end), '[^\w/]', ' ');
        if strncmp(blockName, ignoreBlock, length(ignoreBlock))
            continue;
        end
        makeCopy = false;
        if ~any(strcmp(blocks{i}, oldBlocks))
            % block is only in newModel
            fprintf(1, '++ %s ++\n', blockName);
            makeCopy = true;
        else
            response = 10;
            % block name is common to both models
            newParams = get_param(newBlocks{i}, 'DialogParameters');
            oldParams = get_param(blocks{i}, 'DialogParameters');

            if isstruct(newParams)
                newFields = fieldnames(newParams);
            else
                newFields = {};
            end
            if isstruct(oldParams)
                oldFields = fieldnames(oldParams);
            else
                oldFields = {};
            end

            % report deleted params
            d = setdiff(oldFields, newFields);
            if ~isempty(d)
                fprintf(1, '@@ %s @@\n', blockName);
                response = 1;
                for j = 1:length(d)
                    fprintf(1, '-%s = %s\n', d{j}, num2str(get_param(blocks{i}, d{j})));
                end
                makeCopy = true;
            end

            % report changed params
            for j = 1:length(newFields)
                newValue = get_param(newBlocks{i}, newFields{j});
                if ~isfield(oldParams, newFields{j})
                    % old model is missing this param
                    if response > 4 % show block name if first difference
                        fprintf(1,'@@ %s @@\n', blockName);
                    end
                    fprintf(1, '+%s = %s\n', newFields{j}, num2str(newValue));
                    makeCopy = true; % copy whole block
                else
                    % param exists in both models
                    oldValue = get_param(blocks{i}, newFields{j});
                    if ~isequal(newValue, oldValue) && ~any(strcmp('read-only', ...
                            oldParams.(newFields{j}).Attributes))
                        if response > 4 % show block name if first difference
                            fprintf(1,'@@ %s @@\n', blockName);
                        end
                        fprintf(1, '-%s = %s\n', newFields{j}, num2str(oldValue));
                        fprintf(1, '+%s = %s\n', newFields{j}, num2str(newValue));
                        if ~merge
                            response = 3; % equivalent to 'n'
                        elseif response > 1
                            response = regexpi('aynq', input('Update? [y],n,a,q ', 's'));
                            if isempty(response)
                                response = 2; % default to y
                            end
                        end
                        if 4 == response
                            break
                        elseif response <= 2
                            set_param(blocks{i}, newFields{j}, newValue);
                            updateColor(blocks{i}, 'orange');
                        end
                    end
                end
            end
        end
        if merge && makeCopy
            copyBlock(newBlocks{i}, blocks{i});
            ignoreBlock = blockName; % ignore any childen of blockName
        end
    end

    % return unique destination blocks but do not delete them
    unique = setdiff(oldBlocks, blocks);
    for i = 1:length(unique)
        blockName = regexprep(unique{i}(length(oldModel)+1:end), '[^\w/]', ' ');
        if strncmp(blockName, ignoreBlock, length(ignoreBlock))
            continue;
        end
        ignoreBlock = blockName; % ignore children
        fprintf(1, '-- %s --\n', blockName);
        if merge
            updateColor(unique{i}, 'red');
        end
    end
end

function copyBlock(srcBlock, dstBlock)
%Copies srcBlock to dstBlock.
    block = add_block(srcBlock, dstBlock, 'MakeNameUnique', 'on');
    updateColor(block, 'green');
end

function updateColor(block, color)
%Update block color as directed and change all parents to yellow.
    if strcmp('block', get_param(block, 'type'))
        set_param(block, 'BackgroundColor', color);
        updateColor(get_param(block, 'parent'), 'yellow');
    end
end
