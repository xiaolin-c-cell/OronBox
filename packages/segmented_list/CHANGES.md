# Changes from upstream card_settings_ui 2.0.1

This is a local fork maintained by the OronBox project.

## License

Original work is licensed under the Apache License 2.0.
See the included `LICENSE` file for the full text.

## Modifications

- Fixed Web compatibility by removing the eager `Platform.isMacOS / isLinux / isWindows` field initialization in `SettingsTile`, which threw `Unsupported operation: Platform._operatingSystem` on web builds.
