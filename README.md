# VFX Editor Plugin for Roblox Studio

A powerful, timeline-based plugin for creating, managing, and exporting complex visual effects sequences directly within Roblox Studio.

## Features

- **Timeline Interface**: A familiar, intuitive timeline for sequencing and layering effects.
- **Component-Based System**: Build complex effects by combining different components. Supported types include:
    - `PointLight`, `SpotLight`, `SurfaceLight`
    - `ParticleEmitter`
    - `Sound`
    - `Beam`
    - `Trail`
- **Real-time Preview**: See your effects in action as you build them. Scrub the playhead for precise control or use the playback buttons.
- **Multi-Track Editing**: Standard timeline controls like multi-select (Ctrl+Click), copy (Ctrl+C), and paste (Ctrl+V).
- **Track Organization**:
    - **Vertical Sorting**: Drag and drop tracks vertically to reorder them.
    - **Locking**: Lock tracks to prevent accidental edits.
    - **Solo/Mute**: Isolate specific tracks for easier debugging and refinement.
    - **Labeling**: Double-click a track to rename it.
    - **Group Colors**: Right-click a selection to assign a group color for visual organization.
- **In-Depth Property Editing**: A dedicated properties panel that automatically shows common editable properties for single or multiple selections.
    - **Multi-Select Support**: Intelligently handles multi-selections, showing `<Mixed>` values for properties that differ and allowing you to edit them all at once.
    - **Specialized Controls**: Features custom UI for complex types like `Color3` (with a color picker), `NumberRange`, `ColorSequence` (with a gradient editor), and `Enums`.
- **Undo/Redo**: Full support for undo (Ctrl+Z) and redo (Ctrl+Y) for all state-changing actions, including track sorting.
- **Component Presets**: Quickly create pre-configured particle effects like Fire, Smoke, and Explosions.
- **Safe Save & Load**: Save your entire VFX project and load it back later. Destructive actions like loading and clearing the timeline now have confirmation dialogs to prevent accidental data loss.
- **Export**: Generate a self-contained `ModuleScript` that can be easily integrated into your game to play the VFX sequence at runtime.

## Architecture Overview

The plugin follows a modular architecture, with different "Manager" scripts handling specific responsibilities.

- **`VFXEditor.lua`**: The main plugin script that initializes all managers and connects them.
- **`UIManager.lua`**: Manages the main UI, including the dockable widgets, context menus, and confirmation dialogs.
- **`TimelineManager.lua`**: Handles all logic for the timeline itself, including creating, selecting, moving, resizing, sorting, and pasting tracks.
- **`PropertiesManager.lua`**: Dynamically generates and manages the UI controls in the properties panel based on the selected track(s).
- **`PreviewManager.lua`**: Creates and updates the real-time visual preview of the effect in the workspace.
- **`HistoryManager.lua`**: Manages the undo/redo stacks using a command pattern.
- **`DataManager.lua`**: Handles the serialization and deserialization for saving and loading projects.
- **`Exporter.lua`**: Contains the logic for generating the final runtime `ModuleScript`.
- **`Config.lua` & `Utils.lua`**: Shared modules for configuration (e.g., themes, colors, timeline settings) and utility functions.

## How to Use

1.  **Installation**: Install the plugin from the Roblox marketplace or by placing the plugin folder into your local Roblox Studio plugins directory.
2.  **Creating Effects**: Right-click on the timeline background to open the context menu. From here, you can create new tracks for different component types or use a pre-made preset.
3.  **Editing Tracks**:
    - **Select**: Click a track. Use Ctrl+Click to select multiple tracks.
    - **Move**: Click and drag a selected track horizontally.
    - **Resize**: Click and drag the left or right edge of a track.
    - **Rename**: Double-click the track's label area.
    - **Reorder**: Click and drag a selected track vertically to change its order.
4.  **Editing Properties**: Select one or more tracks. The Properties panel will automatically display all common properties for your selection. Edit the values to see changes in the real-time preview.
5.  **Previewing**:
    - Use the **Play** and **Stop** buttons in the top bar.
    - Click and drag the **red playhead** to "scrub" through the timeline.
6.  **Saving & Loading**: Use the `Save` and `Load` buttons in the top bar to manage your project files. You will be prompted to confirm before loading a project over unsaved work.
7.  **Exporting**: Click `Export`. This will generate a `ModuleScript` in `ServerStorage` containing your entire effect. You can then call the `.play()` method within this module from any server script to trigger the effect.
