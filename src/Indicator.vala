/*
 * Indicator.vala
 *
 * Main wingpanel indicator class
 * Integrates StatusNotifierHost with wingpanel
 */

public class AppicontrayIndicator : Wingpanel.Indicator {
    private Gtk.Box? display_widget = null;
    private StatusNotifierHost host;
    private StatusNotifierWatcher? watcher;

    public AppicontrayIndicator() {
        Object(
            code_name: "appicontray-indicator"
        );
        visible = false;
    }

    construct {
        // Construction and display container
        debug("Constructing AppIconTray Indicator");
        display_widget = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        display_widget.get_style_context().add_class("appicontray");

        // Register D-Bus watcher, print only result of registration
        watcher = new StatusNotifierWatcher();
        watcher.register_on_bus.begin((obj, res) => {
            bool registered = watcher.register_on_bus.end(res);
            if (registered) {
                debug("StatusNotifierWatcher service registered");
            } else {
                debug("Using existing StatusNotifierWatcher service");
            }
            initialize_host();
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
        return display_widget;
    }
    public override Gtk.Widget? get_widget() { return null; }
    public override void opened() {}
    public override void closed() {}

    private void on_icon_added(TrayIcon icon) {
        if (display_widget == null) {
            critical("display_widget is null in on_icon_added!");
            return;
        }
        display_widget.pack_start(icon, false, false, 0);
        icon.show_all();
        visible = true;
    }

    private void on_icon_removed(TrayIcon icon) {
        if (display_widget == null) {
            critical("display_widget is null in on_icon_removed!");
            return;
        }
        display_widget.remove(icon);
        GLib.List<weak Gtk.Widget> children = display_widget.get_children();
        if (children.length() == 0) {
            visible = false;
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

