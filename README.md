## Description
This is a simple tool to help visualize and merge differences between two Simulink models.
See also: [Comparison Tool in Simulink](https://www.mathworks.com/help/simulink/slref/comparisontool.html)

UNIQUE = mergeDiff(OLDMODEL, NEWMODEL{, MERGE=false}) compares block names and dialog parameters from two similar models.  The differences are reported in a format similar to the [unified diff format](http://en.wikipedia.org/wiki/Diff_utility#Unified_format).

If MERGE=true then OLDMODEL will be updated with parameter values and missing blocks from NEWMODEL. The merged model requires manual editing to complete the merge process. The modified blocks in the merged model are color coded upon completion. This function does not examine connecting lines so the user should review and connect these colored blocks manually to complete the merge. 

Background color | Meaning
---------------- | -------
White            | Block is unchanged
Green            | Block was missing from OLDMODEL and was copied from NEWMODEL
Orange           | Block's parameters were updated
Red              | Block is missing from NEWMODEL
Yellow           | Subsystem contains modifications
 
Returns UNIQUE names of blocks found only in OLDMODEL.

## Example
```matlab
% List differences between two Simulink models:
load_system('oldmodel');
open_system('newmodel');
mergeDiff('oldmodel', 'newmodel');
```

![image](https://github.com/costerwi/simulink-mergeDiff/assets/7069475/75092895-b387-4404-86b7-ad4461fed758)
