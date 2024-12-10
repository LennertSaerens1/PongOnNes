# About the Project
We are the NerdSquad, and our mission is to create Pong for the NES.

This project is a collaborative effort by Karel Roelandt, Bram Sprenger, Lennert Saerens, and Thymme Mouchrique. During development, we utilized Visual Studio and the MesenX emulator to ensure a smooth and efficient workflow.

# Instructions to Build and Debug the Project
This project includes a default build folder. If your objective does not involve making modifications, you can simply access the build folder to obtain and run the final build.

### Prerequisites
- Alchemy65 (for Visual Studio Code integration)
- CC65 (for compiling assembly)
  - ensure that the environment variables are correctly set to point to the CC65 compiler
- Mesen/MesenX emulator (for testing)
  - verify that the launch.json file located within the .vs directory is properly configured to reference your mesen.exe executable (when debugging with Visual Studio Code)
- Visual Studio Code (for development and debugging)

### Using Visual Studio Code with Debugger to Edit and Debug (Requires Alchemy65 Installed):
Open the project folder in Visual Studio.
- Locate and open the pong.s file.
- Press Shift + Ctrl + B to build the project. Alternatively, select Run → Start Debugging.
**Ensure the launch.json file within .vs is configured correctly to point to your mesen.exe, and make sure your environments variables are set correctly to point to CC65.**

### Building Outside Visual Studio Code:
* Simply execute the build_outside_vs.bat script.
* Run the resulting .nes file located in the debug folder in your preferred emulator.

# Controls
**Keyboard Controls in emulators are contingent upon the user's configuration settings within the emulator software.** <br> <br>
### NES Controller controls:
D-Pad Up = Move paddle up <br>
D-Pad Down = Move paddle down <br> 
A = Singleplayer <br>
B = Multiplayer <br> 
START = Pause game <br> 

##  References
[Mesen](https://www.mesen.ca) <br>
[Mesen X](https://github.com/NovaSquirrel/Mesen-X) <br>
[CC65](https://cc65.github.io) <br>
[Alchemy65](https://marketplace.visualstudio.com/items?itemName=alchemic-raker.alchemy65) <br>
[How to link visual studio code to your mesen (presentation by Karel)](https://www.mediafire.com/file/w174k29k9ji6ayk/How_to_link_your_VS_code_to_your_Emulator_Presented_By_Karel.pptx/file) <br>
Special thanks to the creators of CC65, Alchemy65, and MesenX for their tools.  
