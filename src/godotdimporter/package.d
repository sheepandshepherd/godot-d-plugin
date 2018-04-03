module godotdimporter;

import godotdimporter.d;

import godot;
import godot.editorplugin, godot.editorimportplugin;

mixin GodotNativeLibrary!(
	"godot_d_importer",
	GodotDImporterPlugin,
	ImportD,
	() => print("Initializing D importer"),
	(GodotTerminateOptions o) => print("Terminating D importer"),
);

@Tool class GodotDImporterPlugin : GodotScript!EditorPlugin
{
	Ref!ImportD d;

	@Method _enterTree()
	{
		d = memnew!ImportD;
		d.resourceFilesystem = owner.getEditorInterface.getResourceFilesystem;
		owner.addImportPlugin(d.owner);
	}

	@Method _exitTree()
	{
		owner.removeImportPlugin(d.owner);
	}
}

