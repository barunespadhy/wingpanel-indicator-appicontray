/*
 * TrayIcon.vala
 *
 * Widget representing a single tray icon
 * Handles display, interaction, and menus
 */

public class TrayIcon : Gtk.EventBox {
    private StatusNotifierItemInterface? item_proxy;
    private FreedesktopStatusNotifierItemInterface? freedesktop_proxy;
    private Gtk.Image icon_image;
    private string service_name;
    private string bus_name;
    private string object_path;
    private DbusmenuGtk.Menu? dbusmenu;
    private bool is_ready = false;
    private bool use_freedesktop_interface = false;
    private DBusConnection? connection;

    public signal void ready();
    public signal void removed();

    public TrayIcon(string service_name, string bus_name, string object_path) {
        this.service_name = service_name;
        this.bus_name = bus_name;
        this.object_path = object_path;

        icon_image = new Gtk.Image();
        icon_image.pixel_size = 16;
        icon_image.margin = 6;
        add(icon_image);

        set_visible_window(false);
        add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.SCROLL_MASK);
        button_press_event.connect(on_button_press);
        scroll_event.connect(on_scroll);

        show_all();
    }

    public async void initialize() {
        debug("Initializing TrayIcon for '%s'", service_name);

        try { connection = yield Bus.get(BusType.SESSION); }
        catch (Error e) {
            critical("TrayIcon failed to get session bus: %s", e.message);
            removed(); return;
        }

        bool success = yield try_kde_interface();
        if (!success) success = yield try_freedesktop_interface();
        if (!success) { removed(); return; }

        yield introspect_properties();

        update_icon();
        update_tooltip();

        try {
            string status = get_status();
            debug("TrayIcon '%s' initial status: '%s'", service_name, status ?? "(null)");
            if (status != null && status != "") handle_status_change(status);
        } catch (Error e) {
            debug("TrayIcon '%s' could not get status: %s", service_name, e.message);
        }

        try {
            var menu_path = get_menu_path();
            if (menu_path != null && menu_path != "/" && menu_path != "") {
                debug("TrayIcon '%s': Initializing DBusMenu at %s", service_name, (string)menu_path);
                dbusmenu = new DbusmenuGtk.Menu(bus_name, menu_path);
            }
        } catch (Error e) {
            debug("TrayIcon '%s': Menu init error: %s", service_name, e.message);
        }

        is_ready = true;
        ready();
    }

    private async void introspect_properties() {
        if (connection == null) return;
        // Only print errors if introspection fails
        try {
            var result = yield connection.call(
                bus_name,
                object_path,
                "org.freedesktop.DBus.Properties",
                "GetAll",
                new Variant("(s)", use_freedesktop_interface ?
                    "org.freedesktop.StatusNotifierItem" :
                    "org.kde.StatusNotifierItem"),
                new VariantType("(a{sv})"),
                DBusCallFlags.NONE,
                -1,
                null
            );
        } catch (Error e) {
            debug("TrayIcon '%s': Error introspecting properties: %s", service_name, e.message);
        }
    }

    private async bool try_kde_interface() {
        try {
            item_proxy = yield Bus.get_proxy<StatusNotifierItemInterface>(
                BusType.SESSION,
                bus_name,
                object_path,
                DBusProxyFlags.NONE
            );
            if (item_proxy == null) return false;
            try { var test_id = item_proxy.Id; }
            catch (Error e) { item_proxy = null; return false; }
            item_proxy.NewIcon.connect(() => update_icon());
            item_proxy.NewStatus.connect((status) => handle_status_change(status));
            item_proxy.NewAttentionIcon.connect(() => update_icon());
            item_proxy.NewTitle.connect(() => update_tooltip());
            use_freedesktop_interface = false;
            return true;
        } catch (Error e) {
            debug("TrayIcon '%s': org.kde interface connection failed: %s", service_name, e.message);
            item_proxy = null;
            return false;
        }
    }

    private async bool try_freedesktop_interface() {
        try {
            freedesktop_proxy = yield Bus.get_proxy<FreedesktopStatusNotifierItemInterface>(
                BusType.SESSION,
                bus_name,
                object_path,
                DBusProxyFlags.NONE
            );
            if (freedesktop_proxy == null) return false;
            try { var test_id = freedesktop_proxy.Id; }
            catch (Error e) { freedesktop_proxy = null; return false; }
            freedesktop_proxy.NewIcon.connect(() => update_icon());
            freedesktop_proxy.NewStatus.connect((status) => handle_status_change(status));
            freedesktop_proxy.NewAttentionIcon.connect(() => update_icon());
            freedesktop_proxy.NewTitle.connect(() => update_tooltip());
            use_freedesktop_interface = true;
            return true;
        } catch (Error e) {
            debug("TrayIcon '%s': org.freedesktop interface connection failed: %s", service_name, e.message);
            freedesktop_proxy = null;
            return false;
        }
    }

    private string? get_icon_name() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.IconName;
            else if (item_proxy != null)
                return item_proxy.IconName;
            return null;
        } catch (Error e) { return null; }
    }

    private string? get_icon_theme_path() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.IconThemePath;
            else if (item_proxy != null)
                return item_proxy.IconThemePath;
            return null;
        } catch (Error e) { return null; }
    }

    private IconPixmapStruct[]? get_icon_pixmap() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.IconPixmap;
            else if (item_proxy != null)
                return item_proxy.IconPixmap;
            return null;
        } catch (Error e) { return null; }
    }

    private string? get_attention_icon_name() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.AttentionIconName;
            else if (item_proxy != null)
                return item_proxy.AttentionIconName;
            return null;
        } catch (Error e) { return null; }
    }

    private IconPixmapStruct[]? get_attention_icon_pixmap() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.AttentionIconPixmap;
            else if (item_proxy != null)
                return item_proxy.AttentionIconPixmap;
            return null;
        } catch (Error e) { return null; }
    }

    private string? get_title() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.Title;
            else if (item_proxy != null)
                return item_proxy.Title;
            return null;
        } catch (Error e) { return null; }
    }

    private string? get_status() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.Status;
            else if (item_proxy != null)
                return item_proxy.Status;
            return null;
        } catch (Error e) { return null; }
    }

    private ObjectPath? get_menu_path() {
        try {
            if (use_freedesktop_interface && freedesktop_proxy != null)
                return freedesktop_proxy.Menu;
            else if (item_proxy != null)
                return item_proxy.Menu;
            return null;
        } catch (Error e) { return null; }
    }

    private void update_icon() {
        if (item_proxy == null && freedesktop_proxy == null) {
            debug("TrayIcon '%s': No proxy available for icon", service_name);
            return;
        }

        string? status = get_status();
        bool needs_attention = (status == "NeedsAttention");
        string? icon_name = needs_attention ? get_attention_icon_name() : get_icon_name();
        if (icon_name == null || icon_name == "") icon_name = get_icon_name();

        if (icon_name != null && icon_name != "") {
            var icon_theme_path = get_icon_theme_path();
            if (icon_theme_path != null && icon_theme_path != "") {
                if (load_icon_from_path(icon_theme_path, icon_name)) return;
                var icon_theme = Gtk.IconTheme.get_default();
                icon_theme.prepend_search_path(icon_theme_path);
            }
            var icon_theme = Gtk.IconTheme.get_default();
            if (icon_theme.has_icon(icon_name)) {
                icon_image.set_from_icon_name(icon_name, Gtk.IconSize.SMALL_TOOLBAR);
                icon_image.pixel_size = 16;
                return;
            }
            if (icon_name.has_prefix("/") && FileUtils.test(icon_name, FileTest.EXISTS)) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(icon_name, 16, 16, true);
                    icon_image.set_from_pixbuf(pixbuf);
                    return;
                } catch (Error e) {}
            }
        }
        IconPixmapStruct[]? pixmaps = needs_attention ? get_attention_icon_pixmap() : get_icon_pixmap();
        if (pixmaps != null && pixmaps.length > 0 && load_icon_from_pixmap(pixmaps)) return;
        icon_image.set_from_icon_name("application-x-executable", Gtk.IconSize.SMALL_TOOLBAR);
        icon_image.pixel_size = 16;
    }

    private bool load_icon_from_path(string base_path, string icon_name) {
        string[] extensions = { ".svg", ".png", ".xpm", "" };
        string[] size_variants = { "", "/16x16", "/scalable", "/hicolor/16x16/apps", "/hicolor/scalable/apps" };
        foreach (var size_dir in size_variants) {
            foreach (var ext in extensions) {
                string icon_file = Path.build_filename(base_path + size_dir, icon_name + ext);
                if (FileUtils.test(icon_file, FileTest.EXISTS)) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_file_at_scale(icon_file, 16, 16, true);
                        icon_image.set_from_pixbuf(pixbuf);
                        return true;
                    } catch (Error e) {}
                }
            }
        }
        return false;
    }

    private bool load_icon_from_pixmap(IconPixmapStruct[] pixmaps) {
        int best_idx = 0;
        int best_diff = int.MAX;
        for (int i = 0; i < pixmaps.length; i++) {
            int size_diff = (pixmaps[i].width - 16).abs() + (pixmaps[i].height - 16).abs();
            if (size_diff < best_diff) {
                best_diff = size_diff;
                best_idx = i;
            }
        }
        var pixmap = pixmaps[best_idx];
        try {
            int width = pixmap.width;
            int height = pixmap.height;
            uint8[] data = pixmap.data;
            int expected_size = width * height * 4;
            if (data.length < expected_size) return false;
            uint8[] rgba_data = new uint8[expected_size];
            for (int i = 0; i < width * height; i++) {
                int src_idx = i * 4;
                int dst_idx = i * 4;
                uint8 a = data[src_idx + 0];
                uint8 r = data[src_idx + 1];
                uint8 g = data[src_idx + 2];
                uint8 b = data[src_idx + 3];
                rgba_data[dst_idx + 0] = r;
                rgba_data[dst_idx + 1] = g;
                rgba_data[dst_idx + 2] = b;
                rgba_data[dst_idx + 3] = a;
            }
            var pixbuf = new Gdk.Pixbuf.from_data(
                rgba_data,
                Gdk.Colorspace.RGB,
                true, 8, width, height, width * 4
            );
            if (width != 16 || height != 16)
                pixbuf = pixbuf.scale_simple(16, 16, Gdk.InterpType.BILINEAR);
            icon_image.set_from_pixbuf(pixbuf);
            return true;
        } catch (Error e) { return false; }
    }

    private void update_tooltip() {
        var title = get_title();
        if (title != null && title != "") set_tooltip_text(title);
    }

    private void handle_status_change(string status) {
        if (status == null || status == "") return;
        visible = (status != "Passive");
        if (status == "NeedsAttention") {
            get_style_context().add_class("needs-attention");
            update_icon();
        } else {
            get_style_context().remove_class("needs-attention");
        }
    }

    private bool on_button_press(Gdk.EventButton event) {
        if (item_proxy == null && freedesktop_proxy == null) return false;
        int x = (int)event.x_root;
        int y = (int)event.y_root;
        try {
            if (event.button == Gdk.BUTTON_PRIMARY) {
                if (use_freedesktop_interface && freedesktop_proxy != null)
                    freedesktop_proxy.Activate.begin(x, y);
                else if (item_proxy != null)
                    item_proxy.Activate.begin(x, y);
            } else if (event.button == Gdk.BUTTON_SECONDARY) {
                if (dbusmenu != null)
                    dbusmenu.popup_at_pointer(event);
                else {
                    if (use_freedesktop_interface && freedesktop_proxy != null)
                        freedesktop_proxy.ContextMenu.begin(x, y);
                    else if (item_proxy != null)
                        item_proxy.ContextMenu.begin(x, y);
                }
            } else if (event.button == Gdk.BUTTON_MIDDLE) {
                if (use_freedesktop_interface && freedesktop_proxy != null)
                    freedesktop_proxy.SecondaryActivate.begin(x, y);
                else if (item_proxy != null)
                    item_proxy.SecondaryActivate.begin(x, y);
            }
        } catch (Error e) {}
        return true;
    }

    private bool on_scroll(Gdk.EventScroll event) {
        if (item_proxy == null && freedesktop_proxy == null) return false;
        int delta = 0;
        string orientation = "vertical";
        switch (event.direction) {
            case Gdk.ScrollDirection.UP: delta = 120; break;
            case Gdk.ScrollDirection.DOWN: delta = -120; break;
            case Gdk.ScrollDirection.LEFT: delta = -120; orientation = "horizontal"; break;
            case Gdk.ScrollDirection.RIGHT: delta = 120; orientation = "horizontal"; break;
            case Gdk.ScrollDirection.SMOOTH:
                double dx, dy;
                event.get_scroll_deltas(out dx, out dy);
                delta = (int)(dy * 120);
                if (dx != 0) { orientation = "horizontal"; delta = (int)(dx * 120);}
                break;
        }
        if (delta != 0) {
            try {
                if (use_freedesktop_interface && freedesktop_proxy != null)
                    freedesktop_proxy.Scroll.begin(delta, orientation);
                else if (item_proxy != null)
                    item_proxy.Scroll.begin(delta, orientation);
            } catch (Error e) {}
        }
        return true;
    }

    public override void dispose() {
        if (item_proxy != null) item_proxy = null;
        if (freedesktop_proxy != null) freedesktop_proxy = null;
        if (dbusmenu != null) dbusmenu = null;
        base.dispose();
    }
}

