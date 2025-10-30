/*
 * StatusNotifierWatcher.vala
 * 
 * Provides StatusNotifierWatcher service on D-Bus
 * Maintains registry of items and hosts
 */

[DBus (name = "org.kde.StatusNotifierWatcher")]
public class StatusNotifierWatcher : Object {
    private const string WATCHER_BUS_NAME = "org.kde.StatusNotifierWatcher";
    private const string WATCHER_OBJECT_PATH = "/StatusNotifierWatcher";
    
    private DBusConnection connection;
    private uint watcher_id = 0;
    private uint registration_id = 0;
    private Gee.ArrayList<string> registered_items;
    private Gee.ArrayList<string> registered_hosts;
    
    public signal void item_registered(string service);
    public signal void item_unregistered(string service);
    public signal void host_registered(string service);
    
    public StatusNotifierWatcher() {
        registered_items = new Gee.ArrayList<string>();
        registered_hosts = new Gee.ArrayList<string>();
    }
    
    public async bool register_on_bus() {
        try {
            connection = yield Bus.get(BusType.SESSION);
            try {
                var has_owner = yield connection.call(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    "org.freedesktop.DBus",
                    "NameHasOwner",
                    new Variant("(s)", WATCHER_BUS_NAME),
                    null,
                    DBusCallFlags.NONE,
                    -1
                );
                
                bool exists;
                has_owner.get("(b)", out exists);
                if (exists) {
                    debug("StatusNotifierWatcher already exists on bus");
                    return false;
                }
            } catch (Error e) {
                warning("Error checking for existing watcher: %s", e.message);
            }
            registration_id = connection.register_object<StatusNotifierWatcher>(WATCHER_OBJECT_PATH, this);
            watcher_id = Bus.own_name(
                BusType.SESSION,
                WATCHER_BUS_NAME,
                BusNameOwnerFlags.NONE,
                on_bus_acquired,
                on_name_acquired,
                on_name_lost
            );
            debug("StatusNotifierWatcher registered and owning name");
            return true;
        } catch (Error e) {
            critical("Failed to register StatusNotifierWatcher: %s", e.message);
            return false;
        }
    }
    
    private void on_bus_acquired(DBusConnection conn) {
        debug("StatusNotifierWatcher bus acquired");
    }
    
    private void on_name_acquired(DBusConnection conn, string name) {
        debug("StatusNotifierWatcher name acquired: %s", name);
    }
    
    private void on_name_lost(DBusConnection conn, string name) {
        warning("StatusNotifierWatcher name lost: %s", name);
    }
    
    public async void RegisterStatusNotifierItem(string service, GLib.BusName sender) throws DBusError, IOError {
        if (registered_items.contains(service)) {
            debug("StatusNotifierItem already registered: %s", service);
            return;
        }
        string service_to_emit;
        string bus_name;
        if (service.has_prefix("/")) {
            service_to_emit = sender + ":" + service;
            bus_name = sender;
            debug("Registering Ayatana format item: %s", service_to_emit);
        } else {
            service_to_emit = service;
            bus_name = service;
            debug("Registering standard SNI item: %s", service_to_emit);
        }
        registered_items.add(service_to_emit);
        item_registered(service_to_emit);
        StatusNotifierItemRegistered(service_to_emit);

        // Monitor when service disconnects
        Bus.watch_name(
            BusType.SESSION,
            bus_name,
            BusNameWatcherFlags.NONE,
            null,
            (conn, name) => {
                unregister_item(service_to_emit);
            }
        );
        debug("StatusNotifierItem registered: %s", service_to_emit);
    }
    
    public async void RegisterStatusNotifierHost(string service) throws DBusError, IOError {
        if (!registered_hosts.contains(service)) {
            registered_hosts.add(service);
            host_registered(service);
            StatusNotifierHostRegistered();
            debug("StatusNotifierHost registered: %s", service);
            Bus.watch_name(
                BusType.SESSION,
                service,
                BusNameWatcherFlags.NONE,
                null,
                (conn, name) => {
                    registered_hosts.remove(service);
                    debug("StatusNotifierHost disconnected: %s", service);
                }
            );
        } else {
            debug("StatusNotifierHost already registered: %s", service);
        }
    }
    
    [DBus (visible = false)]
    public void unregister_item(string service) {
        if (registered_items.remove(service)) {
            debug("Unregistering StatusNotifierItem: %s", service);
            item_unregistered(service);
            StatusNotifierItemUnregistered(service);
        }
    }
    
    public string[] RegisteredStatusNotifierItems {
        owned get {
            return registered_items.to_array();
        }
    }
    
    public bool IsStatusNotifierHostRegistered {
        get {
            return registered_hosts.size > 0;
        }
    }
    
    public int ProtocolVersion {
        get {
            return 0;
        }
    }
    
    public signal void StatusNotifierItemRegistered(string service);
    public signal void StatusNotifierItemUnregistered(string service);
    public signal void StatusNotifierHostRegistered();
}

