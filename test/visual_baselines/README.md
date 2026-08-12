# Visual baselines

These images protect Bonfire's highest-risk UI compositions without snapshotting
every page. The system test captures the sidebar, message history, composer,
account settings, and user profile independently in the explicit dark theme.

Run the check with:

```sh
bin/rails test test/system/visual_regression_test.rb
```

After intentionally reviewing a visual change, regenerate the baselines with:

```sh
UPDATE_VISUAL_BASELINES=1 bin/rails test test/system/visual_regression_test.rb
```

Commit baseline changes with the code that caused them. Do not update baselines
solely to make a failing test pass.
