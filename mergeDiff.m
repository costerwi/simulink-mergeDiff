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
% load_system('oldmodel');
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
        if ~any(strcmp(blocks{i}, oldBlocks))
            % block is new
            fprintf(1, '++ %s ++\n', blockName);
            if merge
                % Insert the new block
                oldBlocks = copyBlock(newBlocks{i}, blocks{i});
            else
                % ignore any childen of blockName
                ignoreBlock = blockName;
            end
        else
            % block name is common to both models
            newParams = get_param(newBlocks{i}, 'DialogParameters');
            oldParams = get_param(blocks{i}, 'DialogParameters');
            if ~isequal(newParams, oldParams)
                % Parameter names are different for block of same name
                % TODO: Report the changed parameter names
                fprintf(1, '!! %s !!\n', blockName);
                if merge
                    % Insert the new block
                    oldBlocks = copyBlock(newBlocks{i}, blocks{i});
                end
            elseif ~isempty(newParams)
                % same parameter names; check if values are different
                flds = fields(newParams);
                response = 10;
                for j = 1:length(flds)
                    srcValue = get_param(newBlocks{i}, flds{j});
                    dstValue = get_param(blocks{i}, flds{j});
                    if ~isequal(srcValue, dstValue) && ~any(strcmp('read-only', ...
                            oldParams.(flds{j}).Attributes))
                        if response > 4 % show block name if first difference
                            fprintf(1,'@@ %s @@\n', blockName);
                        end
                        fprintf(1, '-%s = %s\n', flds{j}, num2str(dstValue));
                        fprintf(1, '+%s = %s\n', flds{j}, num2str(srcValue));
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
                            set_param(blocks{i}, flds{j}, srcValue);
                            updateColor(blocks{i}, 'orange');
                        end
                    end
                end
            end
        end
    end

    % return unique destination blocks but do not delete them
    unique = setdiff(oldBlocks, blocks);
    for i = 1:length(unique)
        blockName = regexprep(unique{i}(length(oldModel)+1:end), '[^\w/]', ' ');
        fprintf(1, '-- %s --\n', blockName);
        if merge
            updateColor(unique{i}, 'red');
        end
    end
end

function [dstBlocks] = copyBlock(srcBlock, dstBlock)
%Copies srcBlock to dstBlock and returns new list of blocks in destination model.
    block = add_block(srcBlock, dstBlock, 'MakeNameUnique', 'on');
    updateColor(block, 'green');
    % Update dstBlocks to include any children of block
    dstBlocks = find_system(bdroot(dstBlock), 'LookUnderMasks', 'all', ...
        'type', 'block');
end

function updateColor(block, color)
%Update block color as directed and change all parents to yellow.
    if strcmp('block', get_param(block, 'type'))
        set_param(block, 'BackgroundColor', color);
        updateColor(get_param(block, 'parent'), 'yellow');
    end
end
