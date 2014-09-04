function [unique] = mergeDiff(srcModel, dstModel)
%mergeDiff Simple merge of two Simulink models, hilighting differences.
% UNIQUE = mergeDiff(SRCMODEL, DSTMODEL) compares block names and dialog 
% parameters from two similar models. In the process, DSTMODEL will
% be updated with parameter values and missing blocks from SRCMODEL.
%
% Blocks are color coded upon completion:
%  White - Block is unique to DSTMODEL or unchanged from SRCMODEL
%  Green - Block was missing from DSTMODEL
%  Orange - Block's parameters were updated
%  Yellow - Subsystem contains modifications
% 
% This function does not examine connecting lines.  The user should review
% and connect these colored blocks manually to complete the merge.
%
% Returns names of blocks unique to DSTMODEL.
%
% EXAMPLE
% % Merge contributions from another Simulink user's model
% load_system('hismodel');
% open_system('mymodel');
% mergeDiff('hismodel', 'mymodel');
%
% Carl Osterwisch, September 2014

    srcModel = getfullname(srcModel); % convert any handles into names
    dstModel = getfullname(dstModel);
    srcBlocks = find_system(srcModel, 'LookUnderMasks', 'all', 'type', 'block');
    blocks = strrep(srcBlocks, srcModel, dstModel); % dstModel blocks to examine
    dstBlocks = find_system(dstModel, 'LookUnderMasks', 'all', 'type', 'block');
    for i = 1:length(blocks)
        if ~any(strcmp(blocks{i}, dstBlocks))
            fprintf(1, '%s is missing; appending to model.\n', blocks{i});
            dstBlocks = copyBlock(srcBlocks{i}, blocks{i});
        else
            srcParams = get_param(srcBlocks{i}, 'DialogParameters');
            dstParams = get_param(blocks{i}, 'DialogParameters');
            if ~isequal(srcParams, dstParams)
                fprintf(1, '%s has different parameter names; appending to model.\n', ...
                    blocks{i});
                dstBlocks = copyBlock(srcBlocks{i}, blocks{i});
            elseif ~isempty(srcParams) 
                % same parameter names; check if values are different
                flds = fields(srcParams);
                response = 10;
                for j = 1:length(flds)
                    srcValue = get_param(srcBlocks{i}, flds{j});
                    dstValue = get_param(blocks{i}, flds{j});
                    if ~isequal(srcValue, dstValue) && ~any(strcmp('read-only', ...
                            dstParams.(flds{j}).Attributes))
                        if response > 4 % show block name if first difference
                            disp(blocks{i})
                        end
                        fprintf(1, '\t%s is: ', flds{j});
                        disp(dstValue);
                        fprintf(1, '\tValue from %s is: ', srcModel);
                        disp(srcValue);
                        if response > 1
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
    % return unique destination blocks
    unique = setdiff(dstBlocks, blocks);
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