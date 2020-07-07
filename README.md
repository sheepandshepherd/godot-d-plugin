Godot-D Plugin
==============
A Godot editor plugin to integrate the D language more closely into the engine.

Features
--------
- Use D source files as NativeScripts. `.gdns` files are no longer needed.
- Build DUB projects in Godot with the D toolbar.

Installation
------------
1. Clone `godot-d-plugin` inside `<your godot project>/addons/` with `git clone --recursive https://github.com/godot-d/godot-d-plugin.git`
2. Build the plugin by running `dub` in `godot-d-plugin`
3. In Godot, go to `Project > Project Settings > Plugins tab` and activate the plugin

Usage
-----
Multiple classes can be in one file, but only the one with a name matching the
filename (case-insensitive) will be referred to by that file. Use `.gdns` files for
the other classes.

Class name and library path can be manually overridden in the Import dock.

TODO
----
DUB projects can't be used as GDNativeLibrary yet. Use a .gdnlib for now.

