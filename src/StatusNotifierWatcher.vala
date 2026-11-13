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

        install_stale_sni_watch ();
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

        // Deduplicate the canonical identifier that will actually be
        // stored and emitted to StatusNotifierHosts.
        if (registered_items.contains(service_to_emit)) {
            debug("StatusNotifierItem already registered: %s", service_to_emit);
            return;
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

    /*
     * APPICONTRAY_STALE_SNI_FIX
     *
     * Remove StatusNotifierItems whose unique D-Bus owner disappears.
     *
     * RegisteredStatusNotifierItems must never retain dead :1.xxx
     * connections. Otherwise Wingpanel keeps rendering stale tray icons.
     */
    private DBusConnection? stale_sni_bus = null;
    private uint stale_sni_subscription = 0;
    private uint stale_sni_sweep = 0;

    /**
     * Owner D-Bus de un item registrado.
     *
     *   ":1.167"                                  -> ":1.167"
     *   ":1.167:/org/ayatana/NotificationItem/x"   -> ":1.167"
     *   "org.telegram.desktop"                     -> "org.telegram.desktop"
     */
    private string? owner_of (string item) {
        if (item.has_prefix (":")) {
            int slash = item.index_of_char ('/');
            return slash > 0 ? item.substring (0, slash) : item;
        }
        return item;
    }

    /**
     * ¿Ese owner D-Bus sigue vivo?
     *
     * GetNameOwner vale para nombres unicos (":1.98") y bien conocidos.
     * OJO con el Variant: la entrada de GetNameOwner es la TUPLA "(s)", no
     * "s" -> con "s" el mensaje sale mal formado, la llamada devuelve null y
     * parece que no hay owner (era justo lo que hacia el sweep purgar icons
     * vivos).
     */
    private async bool owner_alive (string name) {
        try {
            var owner = yield stale_sni_bus.call (
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "GetNameOwner",
                new Variant ("(s)", name),
                null,
                DBusCallFlags.NONE,
                1000
            );
            return owner != null;
        } catch (Error e) {
            // Solo "no hay owner" significa muerto; un timeout u otro error
            // no puede afirmar que la app murio (no se purga por prudencia).
            if (e.message != null &&
                (e.message.contains ("NameHasNoOwner") ||
                 e.message.contains ("NoSuchProcess"))) {
                return false;
            }
            return true;
        }
    }

    /**
     * Comprueba (sin bloquear el main loop) si el owner de un item sigue vivo.
     */
    private async void check_item_owner (string item, string owner) {
        bool alive = yield owner_alive (owner);
        if (!alive) {
            message ("AppIconTray: sweeping stale SNI %s", item);
            unregister_item (item);
        }
    }

    /**
     * Barrido periodico: purga los items cuyo owner D-Bus ya no existe.
     *
     * Es la via determinista (no depende de recibir NameOwnerChanged, que en
     * este entorno no llegaba) y usa unregister_item(), que emite las DOS
     * señales: la local y la D-Bus StatusNotifierItemUnregistered, que es la
     * que necesita StatusNotifierHost para quitar el TrayIcon del panel.
     *
     * Las consultas son ASÍNCRONAS a proposito: con call_sync el panel se
     * congela (y el watchdog lo mata) porque cada consulta bloquea el bus.
     */
    private void sweep_stale_items () {
        foreach (var item in registered_items) {
            var owner = owner_of (item);
            if (owner == null) {
                continue;
            }
            check_item_owner.begin (item, owner);
        }
    }

    private void install_stale_sni_watch () {
        if (stale_sni_subscription != 0) {
            return;
        }

        try {
            stale_sni_bus = Bus.get_sync (BusType.SESSION);

            stale_sni_sweep = GLib.Timeout.add_seconds (5, () => {
                sweep_stale_items ();
                // CONTINUE: con REMOVE el timer se borra tras la primera
                // vuelta y el sweep solo llegaba a correr al arrancar el panel.
                return GLib.Source.CONTINUE;
            });

            stale_sni_subscription = stale_sni_bus.signal_subscribe (
                "org.freedesktop.DBus",
                "org.freedesktop.DBus",
                "NameOwnerChanged",
                "/org/freedesktop/DBus",
                null,
                DBusSignalFlags.NONE,
                (connection,
                 sender_name,
                 object_path,
                 interface_name,
                 signal_name,
                 parameters) => {

                    string name;
                    string old_owner;
                    string new_owner;

                    parameters.get (
                        "(sss)",
                        out name,
                        out old_owner,
                        out new_owner
                    );

                    /*
                     * We only care about a name disappearing completely.
                     *
                     * For unique names:
                     *   name      = :1.167
                     *   old_owner = :1.167
                     *   new_owner = ""
                     *
                     * Well-known names (org.telegram.desktop) are also
                     * handled: their items are registered under that exact
                     * name, so the same match below removes them.
                     */
                    if (
                        old_owner == "" ||
                        new_owner != ""
                    ) {
                        return;
                    }

                    /*
                     * Items can be registered as:
                     *
                     *   :1.167
                     *   :1.167/StatusNotifierItem
                     *   org.telegram.desktop
                     *
                     * Remove every representation belonging to that owner.
                     */
                    string[] dead_items = {};

                    foreach (var item in registered_items) {
                        if (
                            item == name ||
                            item.has_prefix (name + "/")
                        ) {
                            dead_items += item;
                        }
                    }

                    foreach (var item in dead_items) {
                        /*
                         * Use the SAME path as a normal unregistration.
                         *
                         * unregister_item() emits BOTH signals:
                         *   item_unregistered()             (local)
                         *   StatusNotifierItemUnregistered() (D-Bus)
                         *
                         * StatusNotifierHost listens to the D-Bus one to
                         * remove the TrayIcon from the panel. Emitting only
                         * the local signal purged the watcher list but left
                         * the stale icon on screen.
                         */
                        message (
                            "AppIconTray: removing stale SNI %s",
                            item
                        );

                        unregister_item (item);
                    }
                }
            );

        } catch (Error e) {
            warning (
                "AppIconTray: cannot watch D-Bus SNI owners: %s",
                e.message
            );
        }
    }

}

