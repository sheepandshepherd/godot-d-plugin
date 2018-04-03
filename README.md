Godot-D Importer
================
WIP - not ready to be used

Usage
-----
1. Build the plugin with `dub`
2. Copy the `godot-d-importer` folder into `<your godot project>/addons/`
3. In Godot, go to `Project > Project Settings > Plugins tab` and activate the plugin

D source files inside the project folder will now be recognized as NativeScript
classes, so GDNS files are no longer needed.

Multiple classes can be in one file, but only the one with a name matching the
filename (case-insensitive) will be referred to by that file. Use GDNSes for
the other classes.

The importer will search for the closest GDNativeLibrary in or above the folder
each D file is in.

Class name and library path can be manually overridden in the Import dock.

TODO
----
DUB projects can't be used as GDNativeLibrary yet. Use a .gdnlib for now.
