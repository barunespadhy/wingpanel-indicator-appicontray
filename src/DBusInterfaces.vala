/* 
 * DBusInterfaces.vala
 * 
 * StatusNotifierItem Protocol D-Bus Interface Definitions
 * Based on freedesktop.org specifications
 */

[DBus (name = "org.kde.StatusNotifierWatcher")]
public interface StatusNotifierWatcherInterface : Object {
    public abstract async void RegisterStatusNotifierItem(string service) throws Error;
    public abstract async void RegisterStatusNotifierHost(string service) throws Error;
    
    public signal void StatusNotifierItemRegistered(string service);
    public signal void StatusNotifierItemUnregistered(string service);
    public signal void StatusNotifierHostRegistered();
    
    public abstract string[] RegisteredStatusNotifierItems { owned get; }
    public abstract bool IsStatusNotifierHostRegistered { get; }
    public abstract int ProtocolVersion { get; }
}

// Support both org.kde and org.freedesktop interfaces
[DBus (name = "org.kde.StatusNotifierItem")]
public interface StatusNotifierItemInterface : Object {
    // Properties - Core
    public abstract string Category { owned get; }
    public abstract string Id { owned get; }
    public abstract string Title { owned get; }
    public abstract string Status { owned get; }
    public abstract uint32 WindowId { get; }
    
    // Properties - Icons (names)
    public abstract string IconName { owned get; }
    public abstract string IconThemePath { owned get; }
    public abstract string OverlayIconName { owned get; }
    public abstract string AttentionIconName { owned get; }
    public abstract string AttentionMovieName { owned get; }

    // Properties - Icons (pixmap data)
    // Format: array of (width, height, icon_data)
    public abstract IconPixmapStruct[] IconPixmap { owned get; }
    public abstract IconPixmapStruct[] AttentionIconPixmap { owned get; }
    public abstract IconPixmapStruct[] OverlayIconPixmap { owned get; }

    // Properties - Tooltip
    public abstract string ToolTip { owned get; }

    // Properties - Menu
    public abstract ObjectPath Menu { owned get; }
    public abstract bool ItemIsMenu { get; }
    
    // Methods (add debug print if implemented)
    public abstract async void ContextMenu(int x, int y) throws Error;
    public abstract async void Activate(int x, int y) throws Error;
    public abstract async void SecondaryActivate(int x, int y) throws Error;
    public abstract async void Scroll(int delta, string orientation) throws Error;
    
    // Signals
    public signal void NewTitle();
    public signal void NewIcon();
    public signal void NewAttentionIcon();
    public signal void NewOverlayIcon();
    public signal void NewToolTip();
    public signal void NewStatus(string status);
}

// Structure for icon pixmap data
// ARGB32 format in network byte order
public struct IconPixmapStruct {
    public int width;
    public int height;
    public uint8[] data;
}

// Also support the freedesktop.org variant
[DBus (name = "org.freedesktop.StatusNotifierItem")]
public interface FreedesktopStatusNotifierItemInterface : Object {
    public abstract string Category { owned get; }
    public abstract string Id { owned get; }
    public abstract string Title { owned get; }
    public abstract string Status { owned get; }
    public abstract uint32 WindowId { get; }

    public abstract string IconName { owned get; }
    public abstract string IconThemePath { owned get; }
    public abstract string OverlayIconName { owned get; }
    public abstract string AttentionIconName { owned get; }
    public abstract string AttentionMovieName { owned get; }

    public abstract IconPixmapStruct[] IconPixmap { owned get; }
    public abstract IconPixmapStruct[] AttentionIconPixmap { owned get; }
    public abstract IconPixmapStruct[] OverlayIconPixmap { owned get; }

    public abstract string ToolTip { owned get; }
    public abstract ObjectPath Menu { owned get; }
    public abstract bool ItemIsMenu { get; }

    public abstract async void ContextMenu(int x, int y) throws Error;
    public abstract async void Activate(int x, int y) throws Error;
    public abstract async void SecondaryActivate(int x, int y) throws Error;
    public abstract async void Scroll(int delta, string orientation) throws Error;
    
    public signal void NewTitle();
    public signal void NewIcon();
    public signal void NewAttentionIcon();
    public signal void NewOverlayIcon();
    public signal void NewToolTip();
    public signal void NewStatus(string status);
}

