/*
 * Indicator.vala
 *
 * Main wingpanel indicator class
 * Integrates StatusNotifierHost with wingpanel
 */

public class AppicontrayIndicator : Wingpanel.Indicator {
    private Gtk.Grid? display_widget = null;
    private Gtk.Image? display_icon = null;
    private StatusNotifierHost host;
    private StatusNotifierWatcher? watcher;

    public AppicontrayIndicator() {
        Object(
            code_name: "appicontray-indicator"
        );
        this.visible = true;
    }

    construct {
        // Construction and display container
        debug("Constructing AppIconTray Indicator");
        display_icon = new Gtk.Image.from_icon_name("pan-down-symbolic", Gtk.IconSize.MENU);
        display_icon.set_pixel_size(16);
        display_icon.get_style_context().add_class("appicontray-indicator-icon");
        display_icon.set_tooltip_text(_("Other App Indicator Icons"));


        display_widget = new Gtk.Grid();
        display_widget.get_style_context().add_class("appicontray-indicator");

        // Register D-Bus watcher, print only result of registration
        watcher = new StatusNotifierWatcher();
        watcher.register_on_bus.begin((obj, res) => {
            try {
                bool registered = watcher.register_on_bus.end(res);
                if (registered) {
                    debug("StatusNotifierWatcher service registered");
                } else {
                    debug("Using existing StatusNotifierWatcher service");
                }
                initialize_host();
            } catch (GLib.Error e) {
                // Handle the failure to register
                warning("Failed to register StatusNotifierWatcher: %s", e.message);
            }
        });
    }

    private void initialize_host() {
        host = new StatusNotifierHost();
        host.icon_added.connect(on_icon_added);
        host.icon_removed.connect(on_icon_removed);
        host.start.begin();
        debug("StatusNotifierHost initialized");
    }

    public override Gtk.Widget get_display_widget() {
        // Now return the icon instead of null
        return display_icon;
    }
    public override Gtk.Widget? get_widget() { return display_widget; }
    public override void opened() {display_icon.set_from_icon_name("pan-up-symbolic", Gtk.IconSize.MENU);}
    public override void closed() {display_icon.set_from_icon_name("pan-down-symbolic", Gtk.IconSize.MENU);}

    private void on_icon_added(TrayIcon icon) {
        if (display_widget == null) {
            critical("display_widget is null in on_icon_added!");
            return;
        }

        icon.clicked.connect(() => {
            close();
        });

        display_widget.add(icon);
        icon.show_all();
        this.visible = true;
    }

    private void on_icon_removed(TrayIcon icon) {
        if (display_widget == null) {
            critical("display_widget is null in on_icon_removed!");
            return;
        }
        display_widget.remove(icon);
        GLib.List<weak Gtk.Widget> children = display_widget.get_children();
        if (children.length() == 0) {
            this.visible = false;
        }
    }
}

public Wingpanel.Indicator? get_indicator(Module module,
                                          Wingpanel.IndicatorManager.ServerType server_type) {
    debug("Activating AppIconTray Indicator");
    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }
    var indicator = new AppicontrayIndicator();
    return indicator;
}

