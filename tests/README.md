# Tests

GDScript tests use GUT only in development/CI. GUT is fetched from its official upstream at the commit pinned by `tools/ci/install_gut.sh`; the addon is ignored by Git and removed before export so it is not shipped in desktop/Android artifacts.
