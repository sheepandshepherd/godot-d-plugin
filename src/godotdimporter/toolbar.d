module godotdimporter.toolbar;

import godotdimporter;

import godot;
import godot.control.all;

alias OnInit = RAII;

@Tool class DToolbar : GodotScript!HBoxContainer
{
	GodotDImporterPlugin plugin;
	@OnReady!"d" MenuButton d;
	@OnReady!"selectProject" OptionButton selectProject;
	@OnReady!"dubProject" Button dubProject;
	@OnReady!"buildStatus" MenuButton buildStatus;
	@OnReady!"build" Button build;

	enum projectExistsGroup = gs!"DToolbar project exists";

	/// PopupMenu IDs for the $(D d) MenuButton
	enum DId
	{
		newProject = 0,
		dSettings = 2,
	}

	@Method refresh()
	{
		bool projectExists = false;//projects.length > 0;
		getTree().callGroup(projectExistsGroup, gs!"set_visible", projectExists);
	}

	@Method newProject()
	{
		print("New");
	}

	@Method dIdPressed(int id)
	{
		switch(id)
		{
			case DId.newProject:
				newProject();
				break;
			case DId.dSettings:
				break;
			default:
				break;
		}
	}

	@Method _ready()
	{
		d.addFontOverride(gs!"font", getFont(gs!"bold", gs!"EditorFonts"));
		d.getPopup().connect(gs!"id_pressed", owner, gs!"d_id_pressed");
	}
}


