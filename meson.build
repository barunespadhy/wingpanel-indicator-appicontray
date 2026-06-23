project(
    'wingpanel-indicator-appicontray',
    'vala', 'c',
    version: '1.0.0',
    license: 'GPL-3.0+',
    meson_version: '>= 0.58.0'
)

gnome = import('gnome')
i18n = import('i18n')

# Core dependencies
dependencies = [
    dependency('wingpanel'),
    dependency('granite'),
    dependency('gtk+-3.0'),
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('gdk-pixbuf-2.0'),
    dependency('dbusmenu-gtk3-0.4')
]

# Get installation directory safely
wingpanel_dep = dependency('wingpanel')
indicators_dir = wingpanel_dep.get_variable(pkgconfig: 'indicatorsdir')

# Global C arguments
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

# Vala compilation arguments
vala_args = [
    '--pkg=posix',
    '--pkg=dbusmenu-gtk3-0.4',
    '--vapidir=' + meson.current_source_dir() / 'vapi'
]

# Source files
indicator_files = files(
    'src/Indicator.vala',
    'src/DBusInterfaces.vala',
    'src/StatusNotifierWatcher.vala',
    'src/StatusNotifierHost.vala',
    'src/TrayIcon.vala'
)

# Build shared library
shared_library(
    meson.project_name(),
    indicator_files,
    dependencies: dependencies,
    vala_args: vala_args,
    install: true,
    install_dir: indicators_dir
)