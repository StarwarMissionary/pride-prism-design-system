# Chrome start page

A permissionless new-tab extension with search, a clock, local shortcuts and a finite, user-triggered celebration. No remote code, analytics or browsing-data access. Search goes to Google only when you submit it.

Build with `node scripts/build-theme.mjs --palette bisexual --output dist/bisexual`, then load the generated `dist/bisexual/adapters/chrome-start-page` folder through Chrome Extensions. This is separate from the native Chrome theme and needs its own explicit installation choice.

When updating an existing unpacked installation, back up its folder and replace files **at the same installed path**, then reload the extension. Keeping the path/id preserves local shortcut storage. Do not clear extension storage, edit Chrome's preference files, or restart the entire browser. Open a new tab to verify.

Disable the start-page extension to restore Chrome's standard new-tab page, or restore the backed-up files and reload. The browser theme has a separate rollback.
