/*
 * Custom VAPI for DBusMenu GTK3
 * Based on the DBusMenu specification
 */

[CCode (cheader_filename = "libdbusmenu-gtk/menu.h")]
namespace DbusmenuGtk {
    [CCode (cname = "DBUSMENU_GTKMENU_PROP_DBUSMENU_CLIENT")]
    public const string GTKMENU_PROP_DBUSMENU_CLIENT;

    [CCode (type_id = "dbusmenu_gtkmenu_get_type ()", cname = "DbusmenuGtkMenu")]
    public class Menu : Gtk.Menu {
        [CCode (has_construct_function = false, type = "GtkWidget*", cname = "dbusmenu_gtkmenu_new")]
        public Menu (string dbus_name, string dbus_object);
        
        public unowned Dbusmenu.Client get_client ();
        public unowned Dbusmenu.Menuitem get_root ();
    }

    [CCode (type_id = "dbusmenu_gtkclient_get_type ()", cname = "DbusmenuGtkClient")]
    public class Client : Dbusmenu.Client {
        [CCode (has_construct_function = false, type = "DbusmenuGtkClient*")]
        public Client (string dbus_name, string dbus_object);
        
        public static Gtk.MenuItem newitem_base (Dbusmenu.Menuitem item, Gtk.MenuItem parent);
    }
}

[CCode (cheader_filename = "libdbusmenu-glib/menuitem.h,libdbusmenu-glib/client.h")]
namespace Dbusmenu {
    [CCode (type_id = "dbusmenu_menuitem_get_type ()", cname = "DbusmenuMenuitem")]
    public class Menuitem : GLib.Object {
        public signal void about_to_show ();
        public signal void child_added (Menuitem child, uint position);
        public signal void child_moved (Menuitem child, uint new_position, uint old_position);
        public signal void child_removed (Menuitem child);
        public signal void event (string name, GLib.Variant value, uint timestamp);
        public signal void item_activated (uint timestamp);
        public signal void property_changed (string property, GLib.Variant value);
        public signal void realized ();
        public signal void show_to_user (uint timestamp);
    }

    [CCode (type_id = "dbusmenu_client_get_type ()", cname = "DbusmenuClient")]
    public class Client : GLib.Object {
        [CCode (has_construct_function = false)]
        public Client (string dbus_name, string dbus_object);
        
        public Dbusmenu.Menuitem get_root ();
        
        public signal void event_result (Menuitem parent, string property, GLib.Variant value, uint timestamp, GLib.Error error);
        public signal void icon_theme_dirs_changed (void* arg1);
        public signal void item_activate (Menuitem arg1, uint arg2);
        public signal void layout_updated ();
        public signal void new_menuitem (Menuitem arg1);
        public signal void root_changed (Menuitem arg1);
    }

    [CCode (cprefix = "DBUSMENU_", cheader_filename = "libdbusmenu-glib/menuitem.h")]
    public const string MENUITEM_PROP_ACCESSIBLE_DESC;
    public const string MENUITEM_PROP_CHILD_DISPLAY;
    public const string MENUITEM_PROP_DISPOSITION;
    public const string MENUITEM_PROP_ENABLED;
    public const string MENUITEM_PROP_ICON_DATA;
    public const string MENUITEM_PROP_ICON_NAME;
    public const string MENUITEM_PROP_LABEL;
    public const string MENUITEM_PROP_SHORTCUT;
    public const string MENUITEM_PROP_TOGGLE_STATE;
    public const string MENUITEM_PROP_TOGGLE_TYPE;
    public const string MENUITEM_PROP_TYPE;
    public const string MENUITEM_PROP_VISIBLE;
}

