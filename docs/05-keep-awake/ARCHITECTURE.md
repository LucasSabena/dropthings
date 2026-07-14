# Keep Awake architecture

`ModuleRegistry` is the sole owner of Keep Awake enablement. `start()` acquires
the injected `KeepAwakeAssertionProtocol`; `stop()` always releases it. The
legacy settings `enabled`, duration, and deadline fields remain decodable for a
non-destructive migration, but runtime state no longer depends on a second
module-private toggle.

The shared menu-bar presentation marks this module as a lifecycle toggle. The
app shell performs the registry transition, while the module supplies only its
live sun/moon symbol and assertion health.
