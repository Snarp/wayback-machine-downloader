# TODO (SNARP'S)

- Yardoc documentation.

- Restructure main class for readability.

- Add ability to save file list locally instead of just dumping to console.

  * Should probably be caching it in directory by default?

- Ruby 3 compatibility.

- Logging:

  * Currently uses 'puts' only; switch to Logger/SemanticLogger/something

  * Add ability to write to file

  * Add ability to mute large numbers of repetitive messages encountered when using filters

- Filtering:

  * Add ability to pass and store `:only_filter` and `:exclude_filter` as Regex. They can presently can only be Strings, get converted to Regex each time they're used.

  * String filters use 'include?' - should probably be a 'starts_with?' option or something for specific subdirs.

  * Option for extension/filetype-specific filtering?

- Helper module structure:

  * ToRegex and TidyBytes should be probably moved to a `core_ext` dir or similar to make it clearer that monkeypatching is happening.

  * ArchiveAPI and TidyBytes directory structure conflicts with internal structure.

  * TidyBytes is referred to internally as TibyBytes.

  * ArchiveAPI capitalization?
