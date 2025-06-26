# Igor_scripts
Repository for the standard Baden lab OS scripts. Contents are current as of: 26.06.2025

# Installation
Simply drag and drop the User Procedures and Igor Procedures into the Igor Pro 9 User Files, which by default can be find under `C:\Users\user\Documents\WaveMetrics\Igor Pro 9 User Files\`. 

Note: There's no longer any need to mess around inside `C:\Program Files\WaveMetrics\Igor Pro 9 Folder\`, as Igor 9 seems to perfectly handle importing the files correctly from the path above. 

# User customisation
These scripts have been shared back and forth over the years, so you may find some discrepancies or differences to how you have your own scripts set up. 

You may want to change the default parameter settings, that can be done inside `OS_ParameterTable.ipf`. For analysis scripts, where changes tend to have dependencies, is encouraged not to change the base files and instead create your own custom versions that you can import and use by copying a given procedure and tagging it with `myfile_custom_AA.ipf` where `AA` is your initials, or similar. Then changes can be merged into the main file once changes are stable.
