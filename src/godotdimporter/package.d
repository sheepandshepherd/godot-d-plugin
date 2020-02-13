module godotdimporter;

import godotdimporter.d;
import godotdimporter.toolbar;
import godotdimporter.settings;
//import godotdimporter.project;

import godot;
import godot.util.path;
import godot.editorplugin, godot.editorimportplugin;

import godot.resourceloader;
import godot.packedscene;
import godot.control;
import godot.node;

import std.stdio : writefln, writeln;

import containers.dynamicarray;
import dub.recipe.packagerecipe;

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
	//DProject project;

	static struct Package
	{
		enum separator = Package.init;
		/// is separator
		bool empty() const { return path.godot.length == 0; }

		Path path; /// res://-based path to DUB JSON/SDL
		PackageRecipe recipe; /// DUB recipe
	}
	/// DUB packages
	DynamicArray!Package packages;

	@Method refreshPackages()
	{
		import godot.projectsettings;
		import std.file, std.path;
		import std.string;

		while(!packages.empty) packages.removeBack();

		String root = ProjectSettings.globalizePath(gs!"res://");
		CharString rootUtf = root.utf8;

		bool shouldAddSeparator = false;
		bool separatorQueued = false;

		void add(string project)
		{
			import dub.recipe.io;

			if(separatorQueued) packages ~= Package.separator;
			shouldAddSeparator = true;

			Package p;
			p.path.d = project;
			p.recipe = readPackageRecipe(project, null);
			// TODO: does parent recipe name need to be handled here?
			packages ~= p;
		}
		void addSeparator()
		{
			if(shouldAddSeparator)
			{
				separatorQueued = true;
				shouldAddSeparator = false;
			}
		}
		void breadthFirst(string dir)
		{
			DynamicArray!string dirs;
			dirs ~= dir;
			while(dirs.length)
			{
				string d = dirs.front;
				dirs.remove(0);
				foreach(de; dirEntries(d, SpanMode.shallow))
				{
					if(de.isDir && !de.name.baseName.startsWith('.')) dirs ~= de.name;
				}
				foreach(fe; dirEntries(d, "{dub.json,dub.sdl}", SpanMode.shallow))
				{
					if(fe.isFile) add(fe.name);
				}
			}
		}

		// root project
		foreach(de; dirEntries(rootUtf.data, "{dub.json,dub.sdl}", SpanMode.shallow))
		{
			add(de.name);
		}
		addSeparator();
		foreach(de; dirEntries(rootUtf.data, SpanMode.shallow))
		{
			if(de.isDir && !de.name.baseName.startsWith('.') && de.name.baseName != "addons")
			{
				breadthFirst(de.name);
			}
		}
		addSeparator();
		foreach(de; dirEntries(rootUtf.data.buildPath("addons"), SpanMode.shallow))
		{
			if(de.isDir && de.name.baseName != "godot-d-importer")
			{
				breadthFirst(de.name);
			}
		}
	}

	@Method _enterTree()
	{
		refreshPackages();

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

		/+
		project = ResourceLoader.load(gs!"res://addons/godot-d-importer/ui/DProject.tscn")
			.as!PackedScene.instance().as!DProject;
		addChild(project.owner);
		+/
	}

	@Method _ready()
	{
		toolbar.ready();
	}

	@Method _exitTree()
	{
		owner.removeImportPlugin(d.owner);

		removeControlFromContainer(CustomControlContainer.containerToolbar, toolbar.as!Control);
		toolbar.queueFree();
	}
}

