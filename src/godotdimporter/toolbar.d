module godotdimporter.toolbar;

import godotdimporter;

import godot;
import godot.control.all;

@Tool class DToolbar : GodotScript!HBoxContainer
{
	GodotDImporterPlugin plugin;
	@OnReady!"d" MenuButton d;
	@OnReady!"selectProject" OptionButton selectProject;
	@OnReady!"dubProject" Button dubProject;
	@OnReady!"buildStatus" MenuButton buildStatus;
	@OnReady!"build" Button build;

	enum projectExistsGroup = gs!"DToolbar project exists";

	/// res://-based path (same as in plugin.packages) to selected DUB JSON/SDL
	@Property String selected;

	/// PopupMenu IDs for the $(D d) MenuButton
	enum DId
	{
		newProject = 0,
		dSettings = 2,
	}

	/// refresh project list and toolbar when projects are added or deleted
	@Method refreshProjects()
	{
		bool projectExists = plugin.packages.length > 0;
		getTree().callGroup(projectExistsGroup, gs!"set_visible", projectExists);

		if(projectExists)
		{
			int id = 0; /// select old package if it matches, or the first otherwise
			foreach(pi, ref p; plugin.packages)
			{
				int pid = cast(int)pi;
				if(p.empty) selectProject.addSeparator();
				else
				{
					selectProject.addItem(String(p.recipe.name), pid);
					selectProject.setItemMetadata(pid, Variant(p.path));
					if(p.path == selected) id = pid;
				}
			}
			selected = selectProject.getItemMetadata(id).as!String;
			selectProject.select(id);

			refreshStatus();
		}
		else
		{
			selectProject.clear();
			selected = String.init;
		}
	}

	/// refresh status of selected project
	@Method refreshStatus()
	{
	}

	@Method _selectProject(int id)
	{
		if(id == -1) selected = String.init;
		else
		{
			selected = selectProject.getItemMetadata(id).as!String;
			refreshStatus();
		}
	}

	@Method _dIdPressed(int id)
	{
		switch(id)
		{
			case DId.newProject:
				//plugin.newProject.show();
				break;
			case DId.dSettings:
				break;
			default:
				break;
		}
	}

	@Method _buildPressed()
	{
		if(!selected.length) return;

		import std.process;
		import std.string : join;
		import std.path;
		import godot.projectsettings;

		string[] cmd = ["dub build"];

		Config config = Config.none;

		CharString workDir = ProjectSettings.globalizePath(selected).utf8;
		print("D: Building ", selected);

		// FIXME: async with spawnShell and wait
		auto result = executeShell(cmd.join(), null, config, size_t.max, workDir.data.dirName);
		// FIXME: output to D console, possibly one per build job
		// FIXME: result.output loses its formatting
		print(result.output);
		writeln(result.output);
		if(result.status == 0)
		{
			// TODO: update build status and cache hashes of the files from `dub describe`
		}
	}

	@Method ready()
	{
		d.addFontOverride(gs!"font", getFont(gs!"bold", gs!"EditorFonts"));
		d.getPopup().connect(gs!"id_pressed", owner, gs!"_d_id_pressed");

		refreshProjects();
	}
}


