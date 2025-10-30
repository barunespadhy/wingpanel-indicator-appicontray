project(
    'wingpanel-indicator-appicontray',
    'vala', 'c',
    version: '1.0.0',
    license: 'GPL-3.0+'
)

gettext_name = meson.project_name()
gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_name), language:'c')

# Add custom VAPI directory
add_project_arguments(
    '--vapidir', meson.current_source_dir() / 'vapi',
    language: 'vala'
)

# Get wingpanel indicators directory
wingpanel_dep = dependency('wingpanel')
indicators_dir = wingpanel_dep.get_pkgconfig_variable('indicatorsdir')

# Core dependencies
dependencies = [
    wingpanel_dep,
    dependency('granite'),
    dependency('gtk+-3.0'),
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('gdk-pixbuf-2.0')
]

# Add DBusMenu dependencies
dbusmenu_gtk = dependency('dbusmenu-gtk3-0.4', required: true)
dependencies += dbusmenu_gtk

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
    vala_args: [
        '--pkg=posix',
        '--pkg=dbusmenu-gtk3-0.4',
        '--vapidir=' + meson.current_source_dir() / 'vapi'
    ],
    install: true,
    install_dir: indicators_dir
)

