/*
 * Copyright (c) 2019-2020 Dirli <litandrej85@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

namespace Gala.Plugins.SaveWins {
    [DBus (name = "org.freedesktop.login1.Manager")]
    interface ILogindManager : DBusProxy {
        public abstract signal void prepare_for_shutdown (bool start);
    }

	public class Main : Gala.Plugin {
        private Gala.WindowManager? wm = null;
        private Meta.Display display;
#if !HAS_MUTTER330
        private Meta.Screen screen;
#endif
        private Gee.HashMap<string, int> windows_ws;
        private bool init_state;
        private string path_to_cache;
        private GLib.File cache_file;

        private ILogindManager? logind_manager;

        public override void initialize (Gala.WindowManager wm) {
			this.wm = wm;
#if HAS_MUTTER330
            display = wm.get_display ();
#else
            screen = wm.get_screen ();
            display = screen.get_display ();
#endif
            windows_ws = new Gee.HashMap<string, int> ();
            path_to_cache = GLib.Environment.get_user_cache_dir () + "/gala_plugins";
            cache_file = GLib.File.new_for_path (path_to_cache + "/savewins_cache");

            init_state = false;

            try {
                logind_manager = GLib.Bus.get_proxy_sync (BusType.SYSTEM,
                                                          "org.freedesktop.login1",
                                                          "/org/freedesktop/login1");
            } catch (Error e) {
                warning (e.message);
            }

            if (logind_manager != null) {
                logind_manager.prepare_for_shutdown.connect (save_state);
            }

            display.window_created.connect (on_window_created);
		}

        private void load_state () {
            if (cache_file.query_exists ()) {
                try {
                    GLib.DataInputStream dis = new GLib.DataInputStream (cache_file.read ());
                    string line;

                    string[] wm_classes = {};

                    while ((line = dis.read_line ()) != null) {
                        var entry_arr = line.split (";");
                        if (entry_arr.length > 1) {

                            if (!windows_ws.has_key (entry_arr[1])) {
                                windows_ws[entry_arr[1]] = int.parse (entry_arr[0]);
                                wm_classes += entry_arr[1];
                            }
                        }
                    }

                    foreach (var wm_class in wm_classes) {
                        var desktop_file = "%s.desktop".printf (wm_class);
                        var desktop_info = new GLib.DesktopAppInfo (desktop_file);
                        if (desktop_info == null) {
                            desktop_file = desktop_file.ascii_down ().delimit (" ", '-');;
                            desktop_info = new GLib.DesktopAppInfo (desktop_file);
                        }

                        if (desktop_info == null) {
                            warning (@"SaveWins: couldn't match $(wm_class)");
                            continue;
                        }

                        try {
                            desktop_info.launch (null, null);
                        } catch (Error e) {
                            warning (e.message);
                        }
                    }

                    clear_cache ();
                } catch (Error e) {
                    warning (e.message);
                }
            }

        }

        private void save_state (bool start) {
            var settings = new GLib.Settings ("org.gnome.SessionManager");
            if (start && settings.get_boolean ("auto-save-session")) {
#if HAS_MUTTER330
                var ws_manager = display.get_workspace_manager ();
                unowned GLib.List<Meta.Workspace> workspaces_list = ws_manager.get_workspaces ();
#else
                unowned GLib.List<Meta.Workspace> workspaces_list = screen.get_workspaces ();
#endif
                // settings.set_boolean ("auto-save-session", false);
                if (clear_cache ()) {
                    string[] apps_per_ws = {};

                    foreach (var ws in workspaces_list) {
                        var ws_index = ws.workspace_index;
                        foreach (var next_win in ws.list_windows ()) {
                            var wmclass = next_win.get_wm_class ();
                            if (wmclass != "Wingpanel" && wmclass != "Plank") {
                                apps_per_ws += @"$(ws_index);$(wmclass)\n";
                            }
                        }
                    }

                    if (apps_per_ws.length > 0) {
                        try {
                            var dos = new GLib.DataOutputStream (cache_file.create (FileCreateFlags.REPLACE_DESTINATION));

                            foreach (var app_str in apps_per_ws) {
                                try {
                                    dos.put_string (app_str);
                                } catch (Error e) {
                                    warning (e.message);
                                }
                            }

                        } catch (Error e) {
                            warning (e.message);
                        }
                    }
                }
            }
        }

        private void on_window_created (Meta.Window window) {
            var wmclass = window.get_wm_class ();
            if (!init_state) {
                if (wmclass != null && wmclass == "Plank") {
                    init_state = true;
                    load_state ();
                }
            } else {
                if (window.window_type == Meta.WindowType.NORMAL) {
                    if (wmclass != null && windows_ws.has_key (wmclass)) {
                        var win_ws_index = windows_ws[wmclass];
                        if (win_ws_index > 0) {
                            window.change_workspace_by_index (win_ws_index, true);
                        }

                        windows_ws.unset (wmclass);
                        if (windows_ws.size == 0) {
                            display.window_created.disconnect (on_window_created);
                        }
                    }
                }
            }
        }

        private bool clear_cache () {
            try {
                var path = GLib.File.new_for_path (path_to_cache);
                if (!path.query_exists ()) {
                    path.make_directory ();
                }

                if (cache_file.query_exists ()) {
                    cache_file.delete ();
                }

            } catch (Error e) {
                warning (e.message);
                return false;
            }

            return true;
        }

        public override void destroy () {
			if (wm == null) {
				return;
            }
		}
    }
}

public Gala.PluginInfo register_plugin () {
	return Gala.PluginInfo () {
		name = "SaveWins",
		author = "dirli litandrej85@gmail.com",
		plugin_type = typeof (Gala.Plugins.SaveWins.Main),
		provides = Gala.PluginFunction.ADDITION,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}
