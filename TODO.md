# TODO (SNARP'S)

- References to local directory structure need to use `File.join` rather than string concatenation.

- Yardoc documentation.

- Restructure main class for readability.

- Add ability to save file list locally instead of just dumping to console.

    * Should probably be caching it in directory by default?

- Ruby 3 compatibility.

- `ArchiveApi` uses nested arrays instead of hashes for params?

- Logging:

    * Currently uses `puts` only; switch to `Logger`/`SemanticLogger`/something

    * Add ability to write log to file.

    * Add ability to mute large numbers of repetitive messages encountered when using filters.

- Filtering:

    * Add ability to pass and store `:only_filter` and `:exclude_filter` as Regex. They can presently can only be Strings, get converted to Regex each time they're used.

    * String filters use `include?` - should probably be a `starts_with?` option or something for specific subdirs.

    * Option for extension/filetype-specific filtering?

- Testing:
  
    * Travis not being run; URLs etc out-of-date.

    * Test suite does not display progress clearly; needs to say what it's doing when it's doing it.

    * Test suite is too rigid, fails out-of-the-box:

        ```
        $ bundle exec rake test
        Run options: --seed 36188

        # Running:

        .F....FFF.FF...F....

        Finished in 102.103800s, 0.1959 runs/s, 0.1861 assertions/s.

          1) Failure:
        WaybackMachineDownloaderTest#test_all_timestamps_being_respected [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:90]:
        Expected: 68
          Actual: 69

          2) Failure:
        WaybackMachineDownloaderTest#test_file_list_exclude_filter_without_matches [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:69]:
        Expected: 68
          Actual: 69

          3) Failure:
        WaybackMachineDownloaderTest#test_all_get_file_list_curated_size [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:106]:
        Expected: 69
          Actual: 75

          4) Failure:
        WaybackMachineDownloaderTest#test_file_list_curated [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:30]:
        Expected: 20060711191226
          Actual: "20060711191226"

          5) Failure:
        WaybackMachineDownloaderTest#test_file_list_exclude_filter_with_1_match [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:74]:
        Expected: 67
          Actual: 68

          6) Failure:
        WaybackMachineDownloaderTest#test_file_list_by_timestamp [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:39]:
        --- expected
        +++ actual
        @@ -1 +1 @@
        -{:file_url=>"http://www.onlyfreegames.net:80/strat.html", :timestamp=>20060111084756, :file_id=>"strat.html"}
        +{:file_url=>"http://www.onlyfreegames.net:80/arcade.htm", :timestamp=>"20060111094201", :file_id=>"arcade.htm"}


          7) Failure:
        WaybackMachineDownloaderTest#test_file_list_exclude_filter_with_a_regex [wayback-machine-downloader/test/test_wayback_machine_downloader.rb:79]:
        Expected: 31
          Actual: 32

        20 runs, 19 assertions, 7 failures, 0 errors, 0 skips
        rake aborted!
        Command failed with status (1): [ruby -I"lib:test" -I"~/.rbenv/versions/2.6.0-dev/lib/ruby/gems/2.6.0/gems/rake-10.5.0/lib" "~/.rbenv/versions/2.6.0-dev/lib/ruby/gems/2.6.0/gems/rake-10.5.0/lib/rake/rake_test_loader.rb" "test/test*.rb" ]
        ~/.rbenv/versions/2.6.0-dev/bin/bundle:23:in `load'
        ~/.rbenv/versions/2.6.0-dev/bin/bundle:23:in `<main>'
        Tasks: TOP => test
        (See full trace by running task with --trace)
        ```

## DONE

- Helper module structure:

    * __DONE__ `ToRegex` and `TidyBytes` should be probably moved to a `core_ext` dir or similar to make it clearer that monkeypatching is happening.

    * __DONE__ `ArchiveAPI` directory structure conflicts with internal structure.

    * __DONE__ `TidyBytes` is referred to internally as `TibyBytes`.

    * __DONE__ `ArchiveAPI` capitalization?