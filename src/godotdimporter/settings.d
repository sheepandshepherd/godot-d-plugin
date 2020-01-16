module godotdimporter.settings;

import godot, godot.control.all;

import godot.editorsettings;

import std.meta, std.traits;
import std.conv : text;

struct PluginSettings
{
	@DefaultValue!(gs!"dub")
	String dub;

	@Property(Property.Hint.typeString, "4:")
	@DefaultValue!(() => Array.make(gs!"dmd", gs!"ldc2"))
	Array compilers;
}

struct SettingsWrapper(string prefix, Impl)
{
static:
	private __gshared Ref!EditorSettings _sRef;
	private Ref!EditorSettings _settings()
	{
		if(!_sRef) assert(0, typeof(this).stringof~" used before initialization with EditorSettings!");
		return _sRef;
	}

	/++
	Create the editor settings and set up their property infos
	+/
	public void initialize(Ref!EditorSettings editorSettings)
		in(editorSettings)
	{
		if(_sRef) return;
		else synchronized
		{
			if(_sRef) return;

			_sRef = editorSettings;
			static foreach(f; FieldNameTuple!Impl)
			{{
				alias a = Alias!(mixin("Impl."~f));
				alias F = typeof(a);

				alias udas = getUDAs!(mixin("Impl."~f), Property);
				static if(udas.length && !is(udas[0])) enum Property uda = udas[0];
				else enum Property uda = Property.init;
				// init setting
				if(!_sRef.hasSetting(_name!f))
				{
					Variant defval = getDefaultValueFromAlias!(Impl, f)();
					// FIXME: this does not seem to work. It still returns a broken null default that erases the setting
					static if(is(P : Array) || is(P : Dictionary)) if(defval.type == Variant.Type.nil)
					{
						defval = P.make();
					}
					_sRef.setSetting(_name!f, defval);
				}
				Dictionary info = Dictionary.make(gs!"name", _name!f, gs!"type", cast(int)Variant.variantTypeOf!(T!f),
					gs!"hint", cast(int)uda.hint, gs!"hint_string", String(uda.hintString));
				_sRef.addPropertyInfo(info);
			}}
		}
	}

	private String _name(string field)() { return gs!(prefix~"/"~field); }
	private alias T(string field) = mixin("typeof(Impl."~field~")");

	static foreach(f; FieldNameTuple!Impl)
	{
		mixin("static T!f "~f~"() { return _settings.getSetting(_name!f).as!(T!f); }");
		mixin("static void "~f~"(T!f _value) { _settings.setSetting(_name!f, Variant(_value)); }");
	}
}

alias pluginSettings = SettingsWrapper!("gdnative/d", PluginSettings);

@Tool class DSettings : GodotScript!WindowDialog
{
	Ref!EditorSettings settings;

	@Method _ready()
	{
		pluginSettings.initialize(settings);
	}
}

