module godotdimporter.settings;

import godot, godot.control.all;

import godot.editorsettings;

@Tool class DSettings : GodotScript!WindowDialog
{
	Ref!EditorSettings settings;
}

