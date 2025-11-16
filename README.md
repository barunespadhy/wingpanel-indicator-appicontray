# Wingpanel AppIconTray Indicator

Enables support for StatusNotifierItem (Ayatana) tray icons.
<img width="541" height="185" alt="image" src="https://github.com/user-attachments/assets/849ab7d8-29da-4870-ac17-7144be687aa2" />


# Installation

Installation involves downloading dependencies and then installing the Debian package.

### Install dependencies
<pre>sudo apt-get install wingpanel</pre>

### Install the Package
Download the latest .deb file from [releases]([https://github.com/barunespadhy/wingpanel-indicator-appicontray/releases/tag/Latest](https://github.com/barunespadhy/wingpanel-indicator-appicontray/releases/tag/v1.2)) section and install
<pre>sudo dpkg -i ./wingpanel-indicator-appicontray_*_amd64.deb</pre>

### Disable network manager applet (optional but recommended)
Network Manager creates its own applet, which results in two network managers being shown. Elementary's own network manager, and gnome's default network manager. To avoid this, run the following to disable the applet from starting:
<pre>sudo mv /etc/xdg/autostart/nm-applet.desktop /etc/xdg/autostart/nm-applet.desktop.bak</pre>

# Building from source

Building from source involves installing necessary build dependencies and running relevant build commands.

### Install Dependencies

Install these packages (for Ubuntu, elementary OS, Debian, or derivatives):

<pre>sudo apt install meson ninja-build valac libwingpanel-dev libgranite-dev libglib2.0-dev libgtk-3-dev libgee-0.8-dev libdbusmenu-gtk3-dev pkg-config gir1.2-gtk-3.0</pre>

### Clone and build

Clone the repository:
<pre>
git clone https://github.com/barunespadhy/wingpanel-indicator-appicontray.git
cd wingpanel-indicator-appicontray
</pre>

Configure and Build:
<pre>
meson setup build # Configure the build
ninja -C build # Compile and build
</pre>

Installation:
<pre>sudo ninja -C build install</pre>


# Uninstall

If you wish to uninstall the indicator, steps differ based on installation procedure.

If installed via Debian package:
<pre>sudo apt remove wingpanel-indicator-appicontray</pre>

If built from source, then in the cloned directory run:
<pre>sudo ninja -C build uninstall</pre>

### Enable network manager applet (optional but reccommended)
If the network manager applet was diabled, run the following to get it back:
<pre>sudo mv /etc/xdg/autostart/nm-applet.desktop.bak /etc/xdg/autostart/nm-applet.desktop</pre>
