/*
 * StatusNotifierHost.vala
 * 
 * Manages collection of StatusNotifierItem tray icons
 * Coordinates with StatusNotifierWatcher
 */

public class StatusNotifierHost : Object {
    private StatusNotifierWatcherInterface? watcher;
    private Gee.HashMap<string, TrayIcon> icons;
    private string host_service_name;
    private uint host_name_id = 0;
    
    public signal void icon_added(TrayIcon icon);
    public signal void icon_removed(TrayIcon icon);
    
    public StatusNotifierHost() {
        icons = new Gee.HashMap<string, TrayIcon>();
        host_service_name = "org.kde.StatusNotifierHost-%d".printf(Posix.getpid());
    }
    
    public async void start() {
        try {
            // Own our host service name
            host_name_id = Bus.own_name(
                BusType.SESSION,
                host_service_name,
                BusNameOwnerFlags.NONE,
                null,
                null,
                null
            );

            // Give the bus a moment to register our name
            Timeout.add(100, () => {
                connect_to_watcher.begin();
                return false;
            });

        } catch (Error e) {
            critical("Failed to start StatusNotifierHost: %s", e.message);
        }
    }
    
    private async void connect_to_watcher() {
        try {
            // Connect to the watcher
            watcher = yield Bus.get_proxy<StatusNotifierWatcherInterface>(
                BusType.SESSION,
                "org.kde.StatusNotifierWatcher",
                "/StatusNotifierWatcher",
                DBusProxyFlags.NONE
            );
            
            // Register as a host
            yield watcher.RegisterStatusNotifierHost(host_service_name);
            debug("StatusNotifierHost registered on D-Bus: %s", host_service_name);
            
            // Listen for new items
            watcher.StatusNotifierItemRegistered.connect(on_item_registered);
            watcher.StatusNotifierItemUnregistered.connect(on_item_unregistered);
            
            // Register existing items
            foreach (var item_service in watcher.RegisteredStatusNotifierItems) {
                on_item_registered(item_service);
            }
            
        } catch (Error e) {
            critical("Failed to connect to StatusNotifierWatcher: %s", e.message);
            // Retry connection after delay
            Timeout.add_seconds(2, () => {
                connect_to_watcher.begin();
                return false;
            });
        }
    }
    
    private void on_item_registered(string service) {
        // Don't add duplicates
        if (icons.has_key(service)) {
            debug("StatusNotifierItem already exists, skipping: %s", service);
            return;
        }

        string bus_name;
        string object_path;
        
        // Parse the service string - it can be in multiple formats:
        int first_slash = service.index_of("/");
        if (first_slash > 0) {
            string before_slash = service.substring(0, first_slash);
            int last_colon_before_slash = before_slash.last_index_of(":");
            if (last_colon_before_slash > 0) {
                bus_name = service.substring(0, last_colon_before_slash);
                object_path = service.substring(last_colon_before_slash + 1);
                debug("Parsed Ayatana format: bus='%s', path='%s'", bus_name, object_path);
            } else {
                bus_name = service.substring(0, first_slash);
                object_path = service.substring(first_slash);
                debug("Parsed bus/path format: bus='%s', path='%s'", bus_name, object_path);
            }
        } else if (service.has_prefix("/")) {
            debug("Ignored bare object path: %s", service);
            return;
        } else {
            bus_name = service;
            object_path = "/StatusNotifierItem";
            debug("Parsed standard SNI: bus='%s', path='%s'", bus_name, object_path);
        }
        
        var icon = new TrayIcon(service, bus_name, object_path);
        icon.ready.connect(() => {
            icons.set(service, icon);
            icon_added(icon);
        });
        
        icon.removed.connect(() => {
            on_item_unregistered(service);
        });
        
        icon.initialize.begin();
    }
    
    private void on_item_unregistered(string service) {
        debug("StatusNotifierItem unregistered: %s", service);
        var icon = icons.get(service);
        if (icon != null) {
            icon_removed(icon);
            icons.unset(service);
        }
    }
    
    public void stop() {
        if (host_name_id != 0) {
            Bus.unown_name(host_name_id);
            host_name_id = 0;
        }
        
        icons.clear();
    }
}

