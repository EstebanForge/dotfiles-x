import sys

from gi.repository import Gio, GLib

BUS = "org.freedesktop.secrets"
SVC = "/org/freedesktop/secrets"
COLL = "/org/freedesktop/secrets/collection/login"
INTERNAL = "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface"

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)


def call(path, iface, method, args):
    return bus.call_sync(
        BUS, path, iface, method, args, None, Gio.DBusCallFlags.NONE, -1, None
    )


def get_locked():
    r = call(
        COLL,
        "org.freedesktop.DBus.Properties",
        "Get",
        GLib.Variant("(ss)", ("org.freedesktop.Secret.Collection", "Locked")),
    )
    return r.unpack()[0]


session = call(
    SVC,
    "org.freedesktop.Secret.Service",
    "OpenSession",
    # gnome-keyring 50 rejects an empty byte array as the plain-session input; it wants an empty string
    GLib.Variant("(sv)", ("plain", GLib.Variant("s", ""))),
).unpack()[1]

try:
    if get_locked():
        call(
            SVC,
            INTERNAL,
            "UnlockWithMasterPassword",
            GLib.Variant("(o(oayays))", (COLL, (session, b"", b"", "text/plain"))),
        )
    if get_locked():
        sys.exit("login keyring still locked after unlock attempt")
    print("login keyring unlocked")
finally:
    call(session, "org.freedesktop.Secret.Session", "Close", None)
