module godotdimporter.d;

import std.file, std.path;
import std.string;
import std.range;
import std.meta;
import std.typecons : scoped;

import godot;
import godot.editorimportplugin;
import godot.file;
import godot.resource;
import godot.resourceloader, godot.resourcesaver;
import godot.projectsettings;
import godot.nativescript, godot.gdnativelibrary;
import godot.editorfilesystem;

import godot.d.string;

import dparse.parser, dparse.lexer;
import dparse.ast;
import dparse.rollback_allocator;

import dsymbol.conversion : parseModuleSimple;

/// $(D format) with GDNativeLibrary path followed by class name
enum string gdnsFormat = `[gd_resource type="NativeScript" load_steps=2 format=2]

[ext_resource path="%s" type="GDNativeLibrary" id=1]

[resource]

class_name = "%s"
library = ExtResource( 1 )
`;

class GDVisitor : ASTVisitor
{
	// GC danger zone... not sure if scoped!GDVisitor ensures GC sees these on stack
	string moduleName; // last portion only
	string found; // class matching moduleName
	string[] all; // all classes
	string overrideName; // manually set the class; TODO: not implemented yet
	size_t[2][] overrideAttributeRanges;

	alias visit = ASTVisitor.visit;
	override void visit(in ModuleDeclaration m)
	{
		moduleName = m.moduleName.identifiers.back.text;
		debug print("D: parsed module ", moduleName);
		super.visit(m);
	}

	// TODO: not implemented yet
	version(none) override void visit(in AtAttribute a)
	{
		import std.algorithm.searching : canFind;

		if(a.argumentList.items.canFind!(e => (cast(PrimaryExpression)e) && (cast(PrimaryExpression)e).primary.text == "MainClass"))
		{
			debug print("Found MainClass from ", a.startLocation, " to ", a.endLocation);
			overrideAttributeRanges ~= [a.startLocation, a.endLocation];
		}
	}

	override void visit(in ClassDeclaration c)
	{
		auto name = c.name.text;
		all ~= name;
		if(name.toLower == moduleName || name.camelToSnake == moduleName)
		{
			if(!found.empty) throw new Exception("Multiple classes matching the module found");
			found = name;
		}

		debug print("D: Parsed class ", name);
		super.visit(c);
	}
}

@Tool class ImportD : GodotScript!EditorImportPlugin
{
	Array extensions;
	Array options;
	Dictionary optionLib, optionName;
	Dictionary optionIgnoreGdnlib;

	EditorFileSystem resourceFilesystem;

	this()
	{
		extensions = Array.empty_array;
		extensions ~= String("d");

		options = Array.empty_array;
		
		optionIgnoreGdnlib = Dictionary.empty_dictionary;
		optionIgnoreGdnlib[String("name")] = String("ignoreGdnlibLibraries");
		optionIgnoreGdnlib[String("default_value")] = false;
		options ~= optionIgnoreGdnlib;
		
		optionName = Dictionary.empty_dictionary;
		optionName[String("name")] = String("overrideAutodetectedValues/className");
		optionName[String("default_value")] = String.init;
		options ~= optionName;

		optionLib = Dictionary.empty_dictionary;
		optionLib[String("name")] = String("overrideAutodetectedValues/library");
		optionLib[String("default_value")] = GDNativeLibrary.init;
		optionLib[String("property_hint")] = Property.Hint.resourceType;
		optionLib[String("hint_string")] = String("GDNativeLibrary");
		optionLib[String("usage_hint")] = Property.Usage.defaultUsage | Property.Usage.updateAllIfModified;
		options ~= optionLib;
	}
	~this()
	{

	}

	@Method getImporterName() { return String("d.source"); }
	@Method getVisibleName() { return String("D NativeScript Class"); }
	@Method getRecognizedExtensions()
	{
		return extensions;
	}
	@Method getSaveExtension() { return String("gdns"); }
	@Method getResourceType() { return String("NativeScript"); }

	@Method getPresetCount() { return 1; }

	@Method getPresetName(int preset) { return (preset == 0)?String("Default"):String("Unknown"); }

	@Method getImportOptions(int preset) { return options; }

	@Method bool getOptionVisibility(String option, Dictionary options)
	{
		return true;
	}

	@Method @Rename("import") GodotError import_(String sourceFile,
		String savePath, Dictionary options, Array platformVariants, Array genFiles)
	{
		debug print("D: importing ", sourceFile);
		String name, lib;

		try // should fail to import this file only, not crash Godot, no matter what the problem is.
		{
			// first stage: find the library this belongs to
			if(auto gdnlib = options[String("overrideAutodetectedValues/library")].as!GDNativeLibrary) // override library
			{
				lib = gdnlib.resourcePath;
			}
			else
			{
				if(!sourceFile.data.startsWith("res://")) assert(0, "Path must start with res://. Why is a file outside res:// being imported?");
				auto paths = sourceFile.data[6..$].dirName.pathSplitter;

				bool finished = false;
				UpwardsPathSearch: while(!finished) // can't use !path.empty because res:// needs to be checked too
				{
					String subDir = "res://";
					auto pathPart = paths.save;
					while(!pathPart.empty)
					{
						subDir ~= String(pathPart.front)~String("/");
						pathPart.popFront();
					}
					debug print("D: searching path ", subDir, " for project");
					String globalDir = ProjectSettings.globalizePath(subDir);
					CharString u = globalDir.utf8; // FIXME: dirEntries don't work with wider strings...
					foreach(de; dirEntries(u.data, SpanMode.shallow))
					{
						if(!options[String("ignoreGdnlibLibraries")].as!bool
							&& de.name.extension.toLower == ".gdnlib")
						{
							lib = subDir~String(de.name.baseName);
							break UpwardsPathSearch;
						}
						if(de.name.filenameCmp("dub.json")==0 || de.name.filenameCmp("dub.sdl")==0)
						{
							lib = subDir~String(de.name.baseName);
							break UpwardsPathSearch;
						}
					}
					if(paths.empty) finished = true;
					else paths.popBack();
				}
			}
			if(lib.empty) throw new Exception("Couldn't find a library. Maybe override it in Import panel?");

			auto className = options[String("overrideAutodetectedValues/className")].as!String;
			if(!className.empty)
			{
				name = className;
			}
			else
			{
				Ref!File f = memnew!File;
				auto err = f.open(sourceFile, File.Constants.read);
				scope(exit) f.close();
				if(err != GodotError.ok) return err;

				RollbackAllocator rba;
				StringCache sc = StringCache(StringCache.defaultBucketCount);

				String realPathStr = ProjectSettings.globalizePath(sourceFile);
				CharString realPath = realPathStr.utf8;
				ubyte[] bytes = cast(ubyte[])std.file.read(realPath.data);

				LexerConfig lcfg;
				lcfg.fileName = realPath.data;
				auto tokens = getTokensForParser(bytes, lcfg, &sc);

				Module m;
				try m = parseModuleSimple(tokens, realPath.data, &rba);
				catch(Exception e)
				{
					print("Parse error in ", sourceFile, ":\n", e.msg);
					return GodotError.parseError;
				}

				auto visitor = scoped!GDVisitor;
				// for root modules
				visitor.moduleName = sourceFile.utf8.data.idup.baseName.stripExtension;

				m.accept(visitor);

				if(!visitor.found.empty) name = String(visitor.found);
				else if(visitor.all.length == 1) name = String(visitor.all[0]);
				// else: nothing; classless file is acceptable
			}

			{
				import std.format;
				auto dPath = ProjectSettings.globalizePath(savePath~String(".gdns"));
				auto dPathUtf8 = dPath.utf8; // irritating std.file functions
				auto dir = dPathUtf8.data.dirName;
				if(!dir.exists) mkdirRecurse(dir);
				std.file.write(dPathUtf8.data, format!gdnsFormat(lib.utf8.data, name.utf8.data));
			}

			// do what ResourceSaver does to notify the editor of an update
			resourceFilesystem.updateFile(savePath~String(".gdns"));

			return GodotError.ok;
		}
		catch(Exception e)
		{
			print("D import error in ", sourceFile, ":\n", e.msg);
			return GodotError.failed;
		}
	}
}

