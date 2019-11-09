module godotdimporter;

import godotdimporter.d;
import godotdimporter.toolbar;
import godotdimporter.settings;

import godot;
import godot.editorplugin, godot.editorimportplugin;

import godot.resourceloader;
import godot.packedscene;
import godot.control;
import godot.node;

import std.stdio : writefln, writeln;

mixin GodotNativeLibrary!(
	"godot_d_importer",
	() => print("Initializing D importer"),
	(GodotTerminateOptions o) => print("Terminating D importer"),
);

@Tool class GodotDImporterPlugin : GodotScript!EditorPlugin
{
	Ref!ImportD d;
	DToolbar toolbar;
	DSettings settings;

	@Method _enterTree()
	{
		d = memnew!ImportD;
		d.resourceFilesystem = owner.getEditorInterface.getResourceFilesystem;
		owner.addImportPlugin(d.owner);

		print("loading scene");

		toolbar = ResourceLoader.load(gs!"res://addons/godot-d-importer/ui/DToolbar.tscn")
			.as!PackedScene.instance().as!DToolbar;
		toolbar.plugin = this;
		addControlToContainer(CustomControlContainer.containerToolbar, toolbar.owner);

		settings = ResourceLoader.load(gs!"res://addons/godot-d-importer/ui/DSettings.tscn")
			.as!PackedScene.instance().as!DSettings;
		settings.settings = getEditorInterface().getEditorSettings();
		addChild(settings.owner);
	}

	@Method _exitTree()
	{
		owner.removeImportPlugin(d.owner);

		removeControlFromContainer(CustomControlContainer.containerToolbar, toolbar.as!Control);
		toolbar.queueFree();
	}
}

