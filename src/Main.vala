namespace Gala.Plugins.SaveWins {
    [DBus (name = "org.freedesktop.login1.Manager")]
    interface ILogindManager : DBusProxy {
        public abstract signal void prepare_for_shutdown (bool start);
    }

	public class Main : Gala.Plugin {
        private Gala.WindowManager? wm = null;
        private Meta.Display display;

        private Gee.HashMap<string, int> windows_ws;
        private bool init_state;
        private string path_to_cache;
        private GLib.File cache_file;

        private ILogindManager? logind_manager;
        private Bamf.Matcher bamf_matcher;

        public override void initialize (Gala.WindowManager wm) {
			this.wm = wm;
#if HAS_MUTTER3
            display = wm.get_display ();
#endif
#if HAS_MUTTER2
            display = wm.get_screen ().get_display ();
#endif
            windows_ws = new Gee.HashMap<string, int> ();
            path_to_cache = GLib.Environment.get_user_cache_dir () + "/gala_plugins";
            cache_file = GLib.File.new_for_path (path_to_cache + "/savewins_cache");

            init_state = false;

            bamf_matcher = Bamf.Matcher.get_default ();

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

                    string[] desktop_files = {};

                    while ((line = dis.read_line ()) != null) {
                        var entry_arr = line.split (";");
                        if (entry_arr.length > 2) {

                            if (!windows_ws.has_key (entry_arr[1])) {
                                windows_ws[entry_arr[1]] = int.parse (entry_arr[0]);
                                desktop_files += entry_arr[2].replace ("/usr/share/applications/", "");
                            }
                        }
                    }

                    foreach (var desktop_file in desktop_files) {
                        var app_info = new GLib.DesktopAppInfo (desktop_file);
                        if (app_info == null) {
                            continue;
                        }

                        try {
                            app_info.launch (null, null);
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
            if (start) {
                var ws_manager = display.get_workspace_manager ();

                if (clear_cache ()) {
                    string[] apps_per_ws = {};

                    foreach (var ws in ws_manager.get_workspaces ()) {
                        var ws_index = ws.workspace_index;
                        foreach (var next_win in ws.list_windows ()) {
                            var wmclass = next_win.get_wm_class ();
                            if (wmclass != "Wingpanel" && wmclass != "Plank") {
                                var xid = next_win.get_xwindow ();

                                var bamf_app = bamf_matcher.get_application_for_xid ((uint32) xid);
                                if (bamf_app != null) {
                                    apps_per_ws += "%u;%s;%s\n".printf (ws_index,
                                                                        wmclass,
                                                                        bamf_app.get_desktop_file ());
                                }
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